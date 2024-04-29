#require 'selenium-webdriver'
#require 'nokogiri'
#require 'httparty'
require 'pry'
require 'date'
#require './goodreads.rb'  # Allows us to access the ratings on Goodreads
require './nls_bard_sequel.rb' # interface to database
require './nls_book_class.rb'  

@file = File.open("nls_bard_books_all.txt",'r')

@DB = BookDatabase.new
@book_number = 0

@file.each_line do |book|
  @book_number += 1
  book_hash = Book.new(book)
  puts "#{@book_number}, #{book_hash[:title][0..50]}"
  #@DB.insert_book(book_hash, @cat_array)
  #@DB.update_book(book_hash, [])  # Just temporary, to insert all the reading times or other mass updates
  #exit if @book_number > 50
 end
puts "#{@book_number} books processed"

@file.close












# Log in
#auth = {:username=>"mjblyth@gmail.com", :password=>"derbywarin5", :loginid = "mjblyth@gmail.com"}
#url = "https://nlsbard.loc.gov:443/nlsbardprod/login/mainpage/NLS"
#page = HTTParty.get(url, :basic_auth=>auth)
#
#https://nlsbard.loc.gov/nlsbardprod/search/title/page/1/sort/s/srch/A/local/0