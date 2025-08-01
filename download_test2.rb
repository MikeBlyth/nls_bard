require 'selenium-webdriver'
require 'dotenv/load'
require_relative './bard_session_manager'

def debug_log(message)
  puts "[DEBUG] #{Time.now}: #{message}"
end

def download_book(key)
  driver = BardSessionManager.nls_driver
  wait = Selenium::WebDriver::Wait.new(timeout: 15)

  book_url = "https://nlsbard.loc.gov/bard2-web/search/#{key}/"
  debug_log "Navigating to book page: #{book_url}"
  driver.navigate.to book_url

  debug_log 'Waiting for download link'
  download_link = wait.until do
    driver.find_element(:xpath, "//a[starts-with(@href, '/bard2-web/download/#{key}') and contains(., 'Download')]")
  end
  debug_log 'Download link found'

  book_title = download_link.text.sub('Download', '').strip
  debug_log "Initiating download for book: #{book_title} (#{key})"

  debug_log 'Clicking download link'
  download_link.click
  debug_log 'Download link clicked. Please check your downloads folder.'

  debug_log 'Waiting for 10 seconds to allow download to start...'
  sleep 10
  debug_log 'Wait complete.'
end

# Main execution
begin
  debug_log '--- Starting Download Test ---'
  BardSessionManager.initialize_nls_bard_chromium
  download_book('DB60939') # Replace with a valid book key
  debug_log '--- Download Test Completed Successfully ---'
rescue StandardError => e
  debug_log "An error occurred: #{e.message}"
  debug_log e.backtrace.join("\n")
ensure
  debug_log 'Quitting WebDriver session.'
  BardSessionManager.quit
end