require 'sequel'
require 'pry'

class BookDatabase

     attr_accessor :DB, :books, :cats, :wish, :cat_book, :columns
    
	def initialize
	  @DB = Sequel.connect('postgres://mike:asendulf53@localhost/nlsbard')  # This is the whole Sequel Database object
																	        # Referenced as @mybooks.DB in nls_bard.rb
	  @books = @DB[:books]  # Tables ...  									# @mybooks.books
	  @cats = @DB[:cats]
	  @wish = @DB[:wishlist]
	  @cat_book = @DB[:cat_book]
	  @columns = @books.columns # Book columns
	end

	def book_exists?(key)
	  if key.is_a? Book
	     key = key[:key]
	  end
	  q =  @books.where(key: key).empty?
	  return !q
	end

	def cat_exists?(category)
	  q =  @cats.where(category: category).empty?
	  return !q
	end
	
	def cat_book_exists?(category, book_key)
	  q =  @cat_book.where(category: category, book: book_key).empty?
	  return !q
	end

	def insert_cat_book(category, book_key)
	  @cat_book.insert(category: category, book: book_key) unless cat_book_exists?(category, book_key)
	end
	
	def books_with_desired_category
#select CATS.category, BOOKS.* FROM CAT_BOOK LEFT JOIN CATS ON CAT_BOOK.CATEGORY = CATS.CATEGORY 
#   LEFT JOIN BOOKS ON CAT_BOOK.BOOK = BOOKS.KEY 
#   WHERE CATS.DESIRED AND LANGUAGE = 'English'	  
     books = @DB[:cat_book].left_join(:cats, :category=>:category).left_join(:books, :key=>Sequel[:cat_book][:book]).where(:desired=>true, language: "English").distinct(:key)
	end
	
	def find_interesting_books(minimum_year: 0, minimum_stars: 3.8, minimum_ratings: 1000)
	   books_with_desired_category.where{year >= minimum_year}.where{stars >= minimum_stars}.where{ratings >= minimum_ratings}.where(~has_read)
	end
	
	def is_interesting(key, minimum_year: 0, minimum_stars: 3.8, minimum_ratings: 1000)
	   cats = @DB[:cats].right_join(:cat_book, :category=>:category).left_join(:books, :key => Sequel[:cat_book][:book]).
	    where(:key => key).
		where(:desired=>true).
		where(:language=>'English').
		where{year >= minimum_year}.
		where{stars >= minimum_stars}.
		where{ratings >= minimum_ratings}.
		where(has_read: false)
#		binding.pry
	   return !cats.first.nil?
	end
	
	def insert_cat(newcat)
	  @cats.insert(newcat) unless cat_exists?(newcat)
	end  

	def get_book(key)
	  @books.where(key: key).first
	end

	def get_books_by_title(title)
	  @books.filter(Sequel.ilike(:title, "%#{title}%"))
	end

	def get_books_by_author(author)
	  @books.filter(Sequel.ilike(:author, "%#{author}%"))
	end

    def get_by_hash(filters) # This one uses case-insensitive filter and only certain fields
	  if (filters[:key] || '') > ''
	     return @books.where(key: filters[:key])
      end
	  @books.filter(Sequel.ilike(:title, "%#{filters[:title]||''}%") & 
	                Sequel.ilike(:author, "%#{filters[:author]||''}%") & 
					Sequel.ilike(:blurb, "%#{filters[:blurb]||''}%")) 
	end  

	def select_books(filter_hash) # This won't do case-insensitive searches
	  @books.where(filter_hash).all
	end
	
	def update_book_categories(newbook)
	 # 
		@books.filter(key: newbook[:key]).update(categories: newbook[:categories])
	    newbook.category_array.each do |category|
		  insert_cat(category)
		  insert_cat_book(category, newbook[:key])
		end  
	end
	
	def update_book_year(key, year)
	 # 
      if key.is_a? Book
	    key = key[:key]
	  end
   	  @books.filter(key: key).update(year: year)
	end
	
	def update_book_rating(book)
	   @books.filter(key: book[:key]).update(stars: book[:stars], ratings: book[:ratings], stars_date: book[:stars_date], 
	      goodreads_title: book[:goodreads_title],
	      goodreads_author: book[:goodreads_author],)
	end

	def update_book_author_title(book)
	   @books.filter(key: book[:key]).update(title: book[:title],
	      author: book[:author], new_author: book[:new_author], new_title: book[:new_title])
	end

	
	def insert_wish(hash)
	  author = hash[:author]
	  title = hash[:title]
	  if ((title||'') == '') || ((author||'') == '')  # Both title and author are required
			puts "Error - both title and author are required for wish list"
			return
	  end
	  b = get_by_hash(hash).first # See if a matching book is already in the database
	  if b # match
	        if b[:has_read]
				read = "and has already been read"
			else
				read = "but had not yet been read"
			end
			puts "#{b[:title]} by #{b[:author]} is already an NLS BARD book (#{b[:key]})" 
			puts "\t"+read

			return
	  end
	  if @wish.where(Sequel.ilike(:title, '%'+title+'%') & Sequel.ilike(:author, '%'+author+'%')).empty? # Make sure book not already in the list
	    @wish.insert(title: title, author: author)  # Insert it
	  else
	    puts "#{title} by #{author} is already in the wishlist"
	  end
	end
	
	def list_wish  # List the wishlist
	  puts "Wish list:"
	  @wish.each {|w| puts "\t#{w[:title]} by #{w[:author]}"}
	end  
	
	def wish_delete(hash)
	  puts "Deleting from wish list, hash = #{hash}"
	  if (hash[:id]||'') + (hash[:key]||'') + (hash[:title]||'') > ''
	    @wish.filter(hash).delete
	  end
	end
	
	def check_for_wishlist_matches
		joiner =  "SELECT id, books.title, books.author, books.key FROM wishlist INNER JOIN books ON books.title ILIKE Concat('%',wishlist.title,'%') AND books.author ILIKE Concat('%',wishlist.author,'%')"
		matches = @DB[joiner]  # Using raw SQL since I can't figure out the right Sequel form
		if matches.count > 0
		  puts "Found matches to wishlist:"
		  matches.each do |m|
			puts "\t#{m[:title]} by #{m[:author]} (#{m[:key]})"
			mkey = m[:key]
			@wish.filter(id: m[:id]).update(key: m[:key])
		  end
		else
		  puts "No matches found for wishlist items."
		end
	end
	

	def insert_book(newbook)
	  return if book_exists?(newbook[:key])
	  newbook.keys.each {|k| newbook.delete(k) unless @books.columns.include? k} # filter columns not in the database table
      @books.insert(newbook)
      if (newbook.category_array || []).count > 0
	    newbook.category_array.each do |category|
		  insert_cat(category)
		  insert_cat_book(category, newbook[:key])
		end  
	  end  
	end
end
	
