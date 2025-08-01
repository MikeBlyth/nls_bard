# require 'selenium-webdriver'
# require 'nokogiri'
# require 'httparty'
require 'date'
# require './goodreads.rb'  # Allows us to access the ratings on Goodreads
require './nls_bard_sequel' # interface to database
require './nls_book_class'

@file = File.open('nls_bard_books_all.txt', 'r')

@DB = BookDatabase.new
@book_number = 0

@file.each_line do |book|
  @book_number += 1
  book_hash = Book.new(book)
  puts "#{@book_number}, #{book_hash[:title][0..50]}"
  # @DB.insert_book(book_hash, @cat_array)
  # @DB.update_book(book_hash, [])  # Just temporary, to insert all the reading times or other mass updates
  # exit if @book_number > 50
end
puts "#{@book_number} books processed"

@file.close
