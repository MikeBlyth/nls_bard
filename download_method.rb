def login
  return if @logged_in

  @nls_driver.navigate.to 'https://nlsbard.loc.gov/nlsbardprod/login'
  begin
    wait = Selenium::WebDriver::Wait.new(timeout: 10)

    username_field = wait.until { @nls_driver.find_element(name: 'loginid') }
    password_field = @nls_driver.find_element(name: 'password')
    submit_button = @nls_driver.find_element(name: 'submit')

    username_field.send_keys ENV['NLS_BARD_USERNAME']
    password_field.send_keys ENV['NLS_BARD_PASSWORD']
    submit_button.click

    # Wait for login to complete
    wait.until { @nls_driver.current_url != 'https://nlsbard.loc.gov/nlsbardprod/login' }

    @logged_in = true
    puts 'Login successful'
  rescue Selenium::WebDriver::Error::TimeoutError
    puts 'Login page timed out. The site might be slow or unavailable.'
  rescue Selenium::WebDriver::Error::NoSuchElementError
    puts 'Login form elements not found. The page structure might have changed.'
  rescue StandardError => e
    puts 'An error occurred during login: #{e.message}'
  end
end

def initialize_nls_bard_chromium
  return if @nls_driver

  puts 'Initializing Chrome WebDriver...'

  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--enable-logging')
  options.add_argument('--v=1')
  options.add_argument('--enable-chrome-logs')
#  options.add_preference('download.default_directory', '/downloads')

  # Enable performance logging
  options.add_option('goog:loggingPrefs', { performance: 'ALL', browser: 'ALL' })

  puts "Chrome options set: #{options.as_json}"

  service = Selenium::WebDriver::Chrome::Service.new
  puts 'Chrome service created'

  @nls_driver = Selenium::WebDriver.for(:chrome, options:, service:)
  puts 'Chrome WebDriver initialized'

  puts "Chrome version: #{@nls_driver.capabilities['browserVersion']}"
  puts "ChromeDriver version: #{@nls_driver.capabilities['chrome']['chromedriverVersion']}"

  login unless @logged_in
end

def download(key)
  initialize_nls_bard_chromium
  begin
    book_url = "https://nlsbard.loc.gov/nlsbardprod/download/detail/srch/#{key}"
    puts "Navigating to book URL: #{book_url}"
    @nls_driver.navigate.to book_url

    wait = Selenium::WebDriver::Wait.new(timeout: 15)
    puts 'Waiting for download link...'
    download_link = wait.until do
      @nls_driver.find_element(:xpath,
                               "//a[starts-with(@href, 'https://nlsbard.loc.gov/nlsbardprod/download/book/srch/') and contains(text(), 'Download')]")
    end
    puts "Download link found: #{download_link.attribute('href')}"

    book_title = begin
      download_link.find_element(:xpath, './/span').text
    rescue StandardError => e
      puts "Error getting book title: #{e.message}"
      'Unknown Title'
    end

    puts "Initiating download for book: #{book_title} (#{key})"

    puts 'Clicking download link...'
    download_link.click
    puts 'Download link clicked'

    # Search for the downloaded file with progress indication
    # if search_for_download(key)
    #   puts 'Download confirmed.'
    #   # Update your database or perform any other necessary actions here
    # else
    #   puts 'Download not found. It may have failed or been interrupted.'
    # end

    puts "Final URL: #{@nls_driver.current_url}"
  rescue Selenium::WebDriver::Error::TimeoutError => e
    puts "Timeout error: #{e.message}"
    puts "Current URL at timeout: #{@nls_driver.current_url}"
  rescue Selenium::WebDriver::Error::NoSuchElementError => e
    puts "Element not found error: #{e.message}"
  rescue StandardError => e
    puts "An unexpected error occurred: #{e.message}"
    puts e.backtrace.join("\n")
  end
end

def check_network_traffic
  puts 'Checking network traffic...'
  network_events = @nls_driver.logs.get(:performance).select do |entry|
    message = JSON.parse(entry.message)['message']
    message['method'] == 'Network.responseReceived' ||
      message['method'] == 'Network.requestWillBeSent' ||
      message['method'] == 'Network.loadingFinished'
  end

  if network_events.any?
    puts 'Network events found:'
    network_events.each do |event|
      message = JSON.parse(event.message)['message']
      puts "Type: #{message['method']}"
      puts "URL: #{message['params']['request']['url']}" if message['params']['request']
      puts "URL: #{message['params']['response']['url']}" if message['params']['response']
      puts "Status: #{message['params']['response']['status']}" if message['params']['response']
      puts '---'
    end
  else
    puts 'No network events found'
  end
end

def detect_potential_downloads
  puts 'Checking for potential downloads...'
  download_events = @nls_driver.logs.get(:performance).select do |entry|
    message = JSON.parse(entry.message)['message']
    next unless message['method'] == 'Network.responseReceived'

    response = message['params']['response']
    content_type = response['headers']['content-type']
    content_length = response['headers']['content-length'].to_i
    (content_type && content_type.include?('audio')) ||
      (content_length && content_length > 1_000_000) # Arbitrary size, adjust as needed
  end

  if download_events.any?
    puts 'Potential downloads detected:'
    download_events.each do |event|
      message = JSON.parse(event.message)['message']
      response = message['params']['response']
      puts "URL: #{response['url']}"
      puts "Content-Type: #{response['headers']['content-type']}"
      puts "Content-Length: #{response['headers']['content-length']}"
      puts '---'
    end
  else
    puts 'No potential downloads detected'
  end
end

def search_for_download(key, max_wait_time = 300) # 5 minutes max wait time
  download_dir = '/home/chrome/Downloads'
  start_time = Time.now

  loop do
    # Use a more precise find command
    cmd = "find #{download_dir} -type f -name '*#{key}*.zip' -not -name '*.crdownload' 2>/dev/null"
    result = `#{cmd}`

    unless result.strip.empty?
      # File found, return true silently
      return true
    end

    # Print progress indicator
    print '+'
    $stdout.flush

    sleep 1 # Wait for 1 second before checking again

    if Time.now - start_time > max_wait_time
      # Timeout reached, return false silently
      return false
    end
  end
end

def verify_download(headers, key, book_title)
  headers_hash = headers.split("\n").map { |line| line.split(': ', 2) }.to_h

  if headers_hash['content-disposition'] && headers_hash['content-length']
    content_disposition = headers_hash['content-disposition']
    content_length = headers_hash['content-length']

    if content_disposition
      filename = content_disposition.match(/filename="(.+)"/i)&.[](1)
      extracted_key = filename&.match(/DB\d+/i)&.[](0)

      if extracted_key&.upcase == key.upcase
        puts "Successfully initiated download for book: #{book_title}"
        puts "Filename: #{filename}"
        puts "File size: #{content_length} bytes"
        puts "Verified book key: #{extracted_key}"
        update_book_records(key, book_title)
        return true
      else
        puts "Error: Mismatch or missing book key in Content-Disposition. Expected: #{key}, Found: #{extracted_key}"
      end
    else
      puts 'Error: Unable to extract filename from Content-Disposition header'
    end
  else
    puts 'Error: Expected headers (Content-Disposition or Content-Length) not found in the response.'
    puts "Available headers: #{headers_hash.keys.join(', ')}"
  end
  false
end
