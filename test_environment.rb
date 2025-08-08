#!/usr/bin/env ruby

require_relative 'google_sheets_sync'

puts "Environment: #{ENV['BARD_ENVIRONMENT'] || 'not set'}"

gs = GoogleSheetsSync.new
puts "Sheet name will be: #{gs.sheet_name}"

case ENV['BARD_ENVIRONMENT']&.downcase
when 'production'
  puts "✅ Production mode - will use Sheet1"
when 'development', 'dev'
  puts "✅ Development mode - will use Test sheet"
else
  puts "⚠️  Unknown/unset environment - defaulting to Test sheet"
end