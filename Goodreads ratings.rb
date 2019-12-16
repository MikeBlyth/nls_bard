require './goodreads.rb'

puts 'Enter title'
title = gets.chomp
puts 'Enter author'
author = gets.chomp
goodread = goodreadsRating(title, author)
if goodread
  puts "For #{title} the first rating on Goodreads is #{goodread[:stars]}, with #{goodread[:count]} ratings"
else
  puts "No rating found for #{title}"
end
