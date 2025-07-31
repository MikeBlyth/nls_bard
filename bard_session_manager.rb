require 'selenium-webdriver'
require 'dotenv/load'

module BardSessionManager
  @nls_driver = nil
  @logged_in = false

  class << self
    attr_reader :nls_driver
  end

  def self.initialize_nls_bard_chromium
    return if @nls_driver

    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--enable-logging')
    options.add_argument('--v=1')
    options.add_argument('--enable-chrome-logs')

    # Enable performance logging
    options.add_option('goog:loggingPrefs', { performance: 'ALL', browser: 'ALL' })
    service = Selenium::WebDriver::Chrome::Service.new
    @nls_driver = Selenium::WebDriver.for(:chrome, options:, service:)
    login
  end

  def self.login
    return if @logged_in

    login_page = 'https://nlsbard.loc.gov/bard2-web/login/'
    @nls_driver.navigate.to login_page
    begin
      wait = Selenium::WebDriver::Wait.new(timeout: 10)

      login_with_bard_button = wait.until { @nls_driver.find_element(link_text: 'Log in with BARD') }
      login_with_bard_button.click

      username_field = wait.until { @nls_driver.find_element(name: 'username') }
      password_field = @nls_driver.find_element(name: 'password')
      submit_button = @nls_driver.find_element(name: 'login')
      username_field.send_keys ENV['NLS_BARD_USERNAME']
      password_field.send_keys ENV['NLS_BARD_PASSWORD']
      submit_button.click

      wait.until { !@nls_driver.current_url.include?('/login/') }

      @logged_in = true
    rescue Selenium::WebDriver::Error::TimeoutError
      puts 'Login page timed out. The site might be slow or unavailable.'
    rescue Selenium::WebDriver::Error::NoSuchElementError
      puts 'Login form elements not found. The page structure might have changed.'
    rescue StandardError => e
      puts "An error occurred during login: #{e.message}"
    end
  end

  def self.quit
    @nls_driver&.quit
    @nls_driver = nil
    @logged_in = false
  end
end
