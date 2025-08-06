#!/usr/bin/env ruby
require_relative 'nls_bard_sequel'

# Test fuzzy matching with a known wishlist item
db = BookDatabase.new

# Test with "African History of Africa" by "Badawi" - we know this should have a match
puts "Testing fuzzy search for 'African History of Africa' by 'Badawi'"
results = db.get_by_hash_fuzzy({ title: "African History of Africa", author: "Badawi" })
puts "Found #{results.count} results:"
results.each do |book|
  puts "  #{book[:title]} by #{book[:author]} (#{book[:key]})"
end

puts "\nTesting basic search for the same:"
basic_results = db.get_by_hash({ title: "African History of Africa", author: "Badawi" })
puts "Found #{basic_results.count} basic results:"
basic_results.each do |book|
  puts "  #{book[:title]} by #{book[:author]} (#{book[:key]})"
end

# Test with partial title search
puts "\nTesting just title search with 'African'"
title_results = db.get_books_by_title("African")
puts "Found #{title_results.count} title-only results:"
title_results.first(3).each do |book|
  puts "  #{book[:title]} by #{book[:author]} (#{book[:key]})"
end