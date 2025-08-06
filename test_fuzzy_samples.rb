#!/usr/bin/env ruby
require_relative 'nls_bard_sequel'

# Test fuzzy matching with various approximations
db = BookDatabase.new

# Test cases: [wishlist_title, wishlist_author, description]
test_cases = [
  ["Future Face", "Wagner", "compound word test"],
  ["All my knotted up life", "Moore", "hyphenation difference test"], 
  ["African History of Africa", "Badawi", "word order/article test"],
  ["elephants in our glass", "author", "title approximation test"],
  ["elephants on an hourglass", "author", "similar but different title"],
  ["Thomas Cromwell", "Borman", "exact match test"],
  ["Tom Cromwell", "Borman", "nickname approximation"],
  ["Future", "Wagner", "partial title test"],
  ["The Future Face", "Wagner", "extra article test"],
  ["Futureface", "Wagner", "exact compound match"]
]

puts "Testing fuzzy matching with various approximations:\n"
puts "=" * 70

test_cases.each_with_index do |(title, author, description), i|
  puts "\n#{i+1}. #{description.upcase}"
  puts "   Searching: '#{title}' by '#{author}'"
  
  results = db.get_by_hash_fuzzy({ title: title, author: author }).limit(3)
  
  if results.any?
    puts "   Found #{results.count} match(es):"
    results.each do |book|
      puts "     → #{book[:title]} by #{book[:author]} (#{book[:key]})"
    end
  else
    puts "     → No matches found"
  end
end

puts "\n" + "=" * 70
puts "Test completed."