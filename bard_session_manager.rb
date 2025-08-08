require 'selenium-webdriver'
require 'dotenv/load'

# Manages a singleton Selenium WebDriver session for interacting with the
# NLS BARD (Braille and Audio Reading Download) website.
#
# This module is responsible for:
# - Lazily initializing a single Chrome WebDriver instance.
# - Handling the login process to the NLS BARD website using credentials
#   stored in environment variables.
# - Providing a global access point to the WebDriver instance.
# - Ensuring that the login process is only attempted once per session.
# - Providing a method to properly quit the driver and clean up resources.
#
# @example
#   # Initialize the session and log in (if not already done)
#   BardSessionManager.initialize_nls_bard_chromium
#
#   # Get the driver to perform actions
#   driver = BardSessionManager.nls_driver
#   driver.navigate.to 'https://nlsbard.loc.gov/bard2-web/'
#
#   # Quit the session when done
#   BardSessionManager.quit
#
# @note This module requires the `NLS_BARD_USERNAME` and `NLS_BARD_PASSWORD`
#   environment variables to be set for the login to succeed.
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

    # Explicitly set the download directory to ensure files are saved to the mounted volume.
    # This removes ambiguity and makes the download behavior reliable.
    download_path = ENV.fetch('CONTAINER_DOWNLOAD_PATH', '/app/downloads') # Default fallback
    prefs = {
      download: { default_directory: download_path, prompt_for_download: false }
    }
    options.add_preference(:prefs, prefs)

    # Enable performance logging
    options.add_option('goog:loggingPrefs', { performance: 'ALL', browser: 'ALL' })
    service = Selenium::WebDriver::Chrome::Service.new
    @nls_driver = Selenium::WebDriver.for(:chrome, options:, service:)
    login
  end

  def self.login
    return if @logged_in

    login_page = 'https://nlsbard.loc.gov/bard2-web/login/'
    max_retries = 3
    retry_count = 0
    
    begin
      @nls_driver.navigate.to login_page
      wait = Selenium::WebDriver::Wait.new(timeout: 10)

      login_with_bard_button = wait.until { @nls_driver.find_element(link_text: 'Log in with BARD') }
      login_with_bard_button.click

      username_field = wait.until { @nls_driver.find_element(name: 'username') }
      password_field = @nls_driver.find_element(name: 'password')
      submit_button = @nls_driver.find_element(name: 'login')
      username_field.send_keys ENV.fetch('NLS_BARD_USERNAME')
      password_field.send_keys ENV.fetch('NLS_BARD_PASSWORD')
      submit_button.click

      # Wait for redirect away from login page
      wait.until { !@nls_driver.current_url.include?('/login/') }
      
      # Verify we actually reached an authenticated page, not an error page
      verify_successful_login
      
      @logged_in = true
    rescue KeyError => e
      puts "Login failed: Missing environment variable - #{e.message}. Please check your .env file."
      exit(1)
    rescue Selenium::WebDriver::Error::TimeoutError, 
           Selenium::WebDriver::Error::WebDriverError,
           Net::OpenTimeout, Net::ReadTimeout, 
           Errno::ECONNRESET, SocketError => e
      retry_count += 1
      if retry_count <= max_retries
        puts "Network error during login (attempt #{retry_count}/#{max_retries}): #{e.class.name}"
        sleep(2 * retry_count)
        retry
      else
        puts "\n" + "="*60
        puts "FATAL: Failed to login to NLS BARD after #{max_retries} attempts"
        puts "Error: #{e.message}"
        puts "Login is required to access the BARD website."
        puts "Please check your network connection and try again later."
        puts "="*60
        exit(1)
      end
    rescue Selenium::WebDriver::Error::NoSuchElementError
      puts 'Login form elements not found. The page structure might have changed.'
      exit(1)
    rescue StandardError => e
      puts "An unexpected error occurred during login: #{e.message}"
      exit(1)
    end
  end

  def self.verify_successful_login
    current_url = @nls_driver.current_url
    page_source = @nls_driver.page_source
    
    # Check for common login failure indicators
    if current_url.include?('error') || current_url.include?('invalid')
      puts "\n" + "="*60
      puts "❌ LOGIN FAILED: Invalid credentials"
      puts "Current URL indicates login error: #{current_url}"
      puts "Please check your NLS_BARD_USERNAME and NLS_BARD_PASSWORD in .env file"
      puts "="*60
      exit(1)
    end
    
    # Check for error messages in the page content
    if page_source.include?('invalid username') || 
       page_source.include?('invalid password') ||
       page_source.include?('login failed') ||
       page_source.include?('authentication failed') ||
       page_source.include?('Invalid credentials')
      puts "\n" + "="*60
      puts "❌ LOGIN FAILED: Authentication error detected on page"
      puts "Please verify your NLS_BARD_USERNAME and NLS_BARD_PASSWORD in .env file"
      puts "="*60
      exit(1)
    end
    
    # Check that we're on the expected BARD domain and not redirected elsewhere
    unless current_url.include?('nlsbard.loc.gov')
      puts "\n" + "="*60
      puts "❌ LOGIN FAILED: Redirected to unexpected domain"
      puts "Expected: nlsbard.loc.gov, Got: #{current_url}"
      puts "This may indicate authentication failure or site changes"
      puts "="*60
      exit(1)
    end
    
    # Verify we can access authenticated content by checking for expected elements
    begin
      wait = Selenium::WebDriver::Wait.new(timeout: 5)
      # Look for elements that indicate successful authentication
      # This is a basic check - we'll expand this based on what the authenticated page contains
      if page_source.include?('logout') || page_source.include?('sign out') || 
         current_url.include?('bard2-web') && !current_url.include?('login')
        puts "✅ Login successful - authenticated session established"
      else
        puts "\n" + "="*60
        puts "❌ LOGIN FAILED: No authentication indicators found"
        puts "Current URL: #{current_url}"
        puts "Page may not contain expected authenticated content"
        puts "Please verify your credentials and try again"
        puts "="*60
        exit(1)
      end
    rescue Selenium::WebDriver::Error::TimeoutError
      puts "\n" + "="*60
      puts "❌ LOGIN FAILED: Timeout waiting for authenticated page elements"
      puts "This likely indicates invalid credentials"
      puts "="*60
      exit(1)
    end
  end

  def self.quit
    @nls_driver&.quit
    @nls_driver = nil
    @logged_in = false
  end
end
