require 'selenium-webdriver'
require 'open3'

def log(message)
  puts "[#{Time.now}] #{message}"
end

def run_command(command)
  log "Running command: #{command}"
  stdout, stderr, status = Open3.capture3(command)
  log "Command exit status: #{status.exitstatus}"
  log "STDOUT: #{stdout}"
  log "STDERR: #{stderr}"
end

def test_chrome_setup
  chrome_path = 'C:\ChromeForTesting\chrome.exe'
  chromedriver_path = 'C:\ChromeForTesting\chromedriver.exe'

  log "Ruby version: #{RUBY_VERSION}"
  log "Selenium WebDriver version: #{Selenium::WebDriver::VERSION}"
  log "Chrome path: #{chrome_path}"
  log "ChromeDriver path: #{chromedriver_path}"
  puts "Selenium WebDriver version: #{Selenium::WebDriver::VERSION}"

  Selenium::WebDriver::Chrome::Service.driver_path = chromedriver_path

  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--verbose')
  options.add_argument('--log-level=0')
  options.add_argument('--disable-extensions')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')
  options.add_argument('--remote-debugging-port=9222')
  options.binary = chrome_path

  begin
    log "Creating Chrome service..."
    service = Selenium::WebDriver::Chrome::Service.new(path: chromedriver_path)

    log "Creating driver..."
    driver = Selenium::WebDriver.for :chrome, options: options, service: service
    log "Driver created successfully."

    log "Navigating to website..."
    driver.get 'https://www.example.com'
    log "Navigation successful."

    log "Current URL: #{driver.current_url}"
    log "Page title: #{driver.title}"
  rescue => e
    log "Error: #{e.message}"
    log "Backtrace:"
    log e.backtrace.join("\n")

    log "Checking Chrome process..."
    run_command('tasklist /FI "IMAGENAME eq chrome.exe"')
  ensure
    if driver
      log "Quitting driver..."
      driver.quit
      log "Driver quit successfully."
    end
  end
end

log "Starting Chrome and ChromeDriver test..."
test_chrome_setup
log "Test completed."