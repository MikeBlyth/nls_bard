require_relative './bard_session_manager'

puts '--- Starting Login Test ---'

begin
  # Initialize the driver and attempt to log in.
  # This single call handles both setup and the login action.
  BardSessionManager.initialize_nls_bard_chromium

  driver = BardSessionManager.nls_driver

  # Check if the login was successful by verifying the URL.
  # The login method waits until the URL no longer contains '/login/'.
  if driver && !driver.current_url.include?('/login/')
    puts '✅ SUCCESS: Login appears to be successful.'
    puts "   Current URL: #{driver.current_url}"
  else
    puts '❌ FAILURE: Login failed or timed out.'
    puts "   Current URL: #{driver&.current_url || 'Driver not available'}"
  end
rescue StandardError => e
  puts "An unexpected error occurred during the test: #{e.message}"
  puts e.backtrace.join("\n")
ensure
  # Always ensure the driver is quit to clean up the session.
  puts '--- Ending Login Test ---'
  BardSessionManager.quit
end
