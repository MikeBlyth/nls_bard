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

