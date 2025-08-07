#!/usr/bin/env ruby

require_relative 'google_sheets_sync'

puts "Setting read status for testing..."
gs = GoogleSheetsSync.new
result1 = gs.set_read_status_for_testing("future book", "✓")

puts "Result: #{result1}"
puts "Now run './nls-dev.sh -w' to test the simplified sync"