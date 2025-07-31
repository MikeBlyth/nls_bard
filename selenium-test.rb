require 'selenium-webdriver'
require 'fileutils'

# Remove old cache
FileUtils.rm_rf('/home/chrome/.cache/selenium')

# puts 'Checking Chromium and Chromedriver versions...'
# puts `chromium --version`
# puts `chromedriver --version`

# puts 'Setting up Chrome options...'
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless')
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')
options.add_argument('--disable-gpu')
options.binary = '/usr/bin/google-chrome'

# puts 'Setting up Selenium WebDriver...'
# Selenium::WebDriver.logger.level = :debug

begin
  driver = Selenium::WebDriver.for(:chrome, options:)

  # puts 'Setting page load timeout...'
  # driver.manage.timeouts.page_load = 60 # Increase timeout to 60 seconds

  # puts 'Navigating to website...'
  driver.get 'https://nlsbard.loc.gov/'

  puts "Page loaded. Title: #{driver.title}"
  puts "Current URL: #{driver.current_url}"
rescue StandardError => e
  puts "An error occurred: #{e.message}"
  puts e.backtrace
ensure
  if defined?(driver)
    puts 'Quitting driver...'
    driver.quit
  end
end
