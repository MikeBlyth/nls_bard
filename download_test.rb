require 'selenium-webdriver'
require 'dotenv/load'

def debug_log(message)
  puts "[DEBUG] #{Time.now}: #{message}"
end

debug_log 'Script started'
debug_log "Ruby version: #{RUBY_VERSION}"
debug_log "Selenium WebDriver version: #{Selenium::WebDriver::VERSION}"

begin
  debug_log 'Checking Chrome version'
  chrome_version = `google-chrome --version`.strip
  debug_log "Chrome version: #{chrome_version}"
rescue StandardError => e
  debug_log "Error checking Chrome version: #{e.message}"
end

begin
  debug_log 'Checking ChromeDriver version'
  chromedriver_version = `chromedriver --version`.strip
  debug_log "ChromeDriver version: #{chromedriver_version}"
rescue StandardError => e
  debug_log "Error checking ChromeDriver version: #{e.message}"
end

def initialize_driver
  debug_log 'Initializing WebDriver'

  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  #  options.add_preference('download.prompt_for_download', false)
  #  options.add_preference('download.default_directory', '/tmp/downloads')

  service = Selenium::WebDriver::Chrome::Service.new
  debug_log 'Chrome options set'

  begin
    driver = Selenium::WebDriver.for(:chrome, options:, service:)
    debug_log 'WebDriver initialized successfully'
    driver
  rescue StandardError => e
    debug_log "Error initializing WebDriver: #{e.message}"
    debug_log e.backtrace.join("\n")
    raise
  end
end

# ... [rest of the script remains the same] ...

# Main execution
begin
  driver = initialize_driver
  login(driver)
  download_book(driver, 'DB60939') # Replace with the desired book key
  debug_log 'Script completed successfully'
rescue StandardError => e
  debug_log "An error occurred: #{e.message}"
  debug_log e.backtrace.join("\n")
ensure
  if driver
    debug_log 'Quitting WebDriver'
    driver.quit
  end
  debug_log 'Script ended'
end
