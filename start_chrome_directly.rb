require 'open3'
require 'fileutils'

def log(message)
  puts "[#{Time.now}] #{message}"
end

def run_command(command)
  log "Running command: #{command}"
  stdout, stderr, status = Open3.capture3(command)
  log "Exit status: #{status.exitstatus}"
  log "STDOUT: #{stdout}"
  log "STDERR: #{stderr}"
end

chrome_path = 'C:\ChromeForTesting\chrome.exe'
log_file = 'chrome_verbose.log'

FileUtils.rm_f(log_file)  # Remove old log file if it exists

log "Attempting to start Chrome with verbose logging..."
run_command("\"#{chrome_path}\" --no-sandbox --disable-gpu --headless --enable-logging --v=1 --log-file=\"#{log_file}\" about:blank")

log "Checking for Chrome process..."
run_command('tasklist /FI "IMAGENAME eq chrome.exe"')

log "Contents of #{log_file}:"
puts File.read(log_file) if File.exist?(log_file)