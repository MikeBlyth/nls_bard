# Autmatically download and install the latest chromedriver.exe
# written with assistance of Bard AI

require 'net/http'
require 'open-uri'
require 'zip'
require 'byebug'

# Get the HTML from the webpage
url = 'https://googlechromelabs.github.io/chrome-for-testing/#stable'
response = Net::HTTP.get_response(URI(url))

# Check if the request was successful
byebug
if response.code != '200'
  raise "Error: Failed to fetch webpage. Response code: #{response.code}"
  exit 1
end

# Find the stable version number
stable_version_regex = /Stable.*?<td><code>(.*?)<\/code>/
version_match = stable_version_regex.match(response.body)
# Check if the version number was found
if !version_match
  raise "Error: Stable version not found in the webpage."
  exit 1
end

# Define the download_url and destination path
driver_version = version_match[1]
if response.body =~ /(https:[^<>]*?#{driver_version}[^<>]*?chromedriver-win64.zip)/
 download_url = $1
end

#download_url = "https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/#{driver_version}/win64/chromedriver-win64.zip"
download_path = "D:/users/mike/downloadsD/chromedriver-win64.zip"

# Download the chromedriver file (this version of Ruby needs bare (system) open and not OpenURI.open
begin
  open(download_url) do |f|
    File.open(download_path, 'wb') do |file|
      file.write(f.read)
    end
  end 
rescue StandardError => e
  raise "Error: Failed to download chromedriver.zip: #{e.message} at 
	#{download_url}"
  exit 1
end

# Check if the download file exists before attempting to unzip
if !File.exist?(download_path)
  raise "Error: Downloaded chromedriver.zip not found at #{download_path}"
  exit 1
end

# Extract the chromedriver files directly into chromedriver_folder, ignoring file structure
chromedriver_folder = File.join('D:', 'Program Files (x86)', 'chromedriver')
FileUtils.mkdir_p(chromedriver_folder)

Zip::File.open(download_path) do |zip_file|
  zip_file.each do |entry|
    # Skip directories in the zip file
    next if entry.directory?

	# Need to strip folder name from entry in order to delete existing file
	entry.name =~ /.*\/(.*)/
	dest_file = $1
	destination = File.join(chromedriver_folder, $1)
	puts destination
    File.delete(destination) if File.exist?(destination)

    entry.extract(destination)
  end
end

# Clean up downloaded file
File.delete(download_path)

puts "Successfully downloaded and extracted Chromedriver version #{driver_version} directly into D:\\Program Files (x86)\\chromedriver\\, ignoring file structure."