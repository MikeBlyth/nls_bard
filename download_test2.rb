require 'selenium-webdriver'
require 'dotenv/load'

def debug_log(message)
  puts "[DEBUG] #{Time.now}: #{message}"
end

debug_log "Script started"
debug_log "Ruby version: #{RUBY_VERSION}"
debug_log "Selenium WebDriver version: #{Selenium::WebDriver::VERSION}"

def initialize_driver
  debug_log "Initializing WebDriver"
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')

  debug_log "Chrome options set"
  
  begin
    service = Selenium::WebDriver::Chrome::Service.new
    driver = Selenium::WebDriver.for(:chrome, options: options, service: service)
    debug_log "WebDriver initialized successfully"
    driver
  rescue StandardError => e
    debug_log "Error initializing WebDriver: #{e.message}"
    debug_log e.backtrace.join("\n")
    raise
  end
end

def login(driver)
  debug_log "Navigating to login page"
  driver.navigate.to 'https://nlsbard.loc.gov/nlsbardprod/login'
  wait = Selenium::WebDriver::Wait.new(timeout: 10)

  debug_log "Waiting for username field"
  username_field = wait.until { driver.find_element(name: 'loginid') }
  debug_log "Username field found"
  password_field = driver.find_element(name: 'password')
  submit_button = driver.find_element(name: 'submit')

  debug_log "Entering credentials"
  username_field.send_keys ENV['NLS_BARD_USERNAME']
  password_field.send_keys ENV['NLS_BARD_PASSWORD']
  
  debug_log "Clicking submit button"
  submit_button.click

  debug_log "Waiting for login to complete"
  wait.until { driver.current_url != 'https://nlsbard.loc.gov/nlsbardprod/login' }
  debug_log 'Login successful'
end

def download_book(driver, key)
  book_url = "https://nlsbard.loc.gov/nlsbardprod/download/detail/srch/#{key}"
  debug_log "Navigating to book page: #{book_url}"
  driver.navigate.to book_url
  wait = Selenium::WebDriver::Wait.new(timeout: 15)

  debug_log "Waiting for download link"
  download_link = wait.until do
    driver.find_element(:xpath, "//a[starts-with(@href, 'https://nlsbard.loc.gov/nlsbardprod/download/book/srch/') and contains(text(), 'Download')]")
  end
  debug_log "Download link found"

  book_title = download_link.find_element(:xpath, './/span').text rescue 'Unknown Title'
  debug_log "Initiating download for book: #{book_title} (#{key})"

  debug_log "Clicking download link"
  download_link.click
  debug_log "Download link clicked. Please check your downloads folder."

  debug_log "Waiting for 10 seconds to allow download to start"
  sleep 10
  debug_log "Wait complete"
end

# Main execution
begin
  driver = initialize_driver
  login(driver)
  download_book(driver, 'DB60939')  # Replace with the desired book key
  debug_log "Script completed successfully"
rescue StandardError => e
  debug_log "An error occurred: #{e.message}"
  debug_log e.backtrace.join("\n")
ensure
  if driver
    debug_log "Quitting WebDriver"
    driver.quit
  end
  debug_log "Script ended"
end