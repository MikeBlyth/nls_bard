require 'bundler/setup'
require 'selenium-webdriver'
#****************************************************************************
# If you get an error about chromeddriver being outdated or incompatible, then go to
	# https://chromedriver.chromium.org/downloads
# and download the version that matches the current version of Chrome. Hopefully there will
# always be a compatible one!
# Extract the file chromedriver.exe to D:\Program Files (x86)\chromedriver\
#****************************************************************************1
require 'nokogiri'
require 'httparty'
require 'date'
require './goodreads.rb'  # Allows us to access the ratings on Goodreads
require './nls_bard_sequel.rb' # interface to database
require './nls_book_class.rb'
require './nls_bard_command_line_options.rb'
require 'shellwords'  # turns string into command-line-like args
require 'csv'
require 'zip'
require 'nameable'
require 'readline'

@book_number = 0

def login
	@nls_driver.navigate.to "https://nlsbard.loc.gov/nlsbardprod/login"
    begin
		@nls_driver.find_element(:name, "loginid").send_keys "mjblyth@gmail.com"
		@nls_driver.find_element(:name, "password").send_keys "derbywarin5"
		@nls_driver.find_element(:name, "submit").click
		@logged_in = true
		rescue Selenium::WebDriver::Error::NoSuchElementError
		  puts "Element not found in NLS BARD login page; may be changed or offline"
		  print "Press enter to continue: "
		  gets
		  raise SystemExit
	end
end


def get_page(letter,page, base_url)
  url = "https://nlsbard.loc.gov/nlsbardprod/search/title/page/<page>/sort/s/srch/<letter>/local/0"
  url = base_url.sub(/<page>/, page.to_s).sub(/<letter>/, letter)
  @nls_driver.navigate.to url
  return @nls_driver.page_source
end

# Process raw HTML and return array of plain text entries
def process_page(page)
  parsed = Nokogiri::HTML(page)
  lp = parsed.xpath("//a[contains(text(),'Last Page')]/@href")  # Find "last page" link
  if lp  # last page link found
    # lp will be URL something like "https://nlsbard.loc.gov:443/nlsbardprod/search/title/page/2/sort/s/local/0/srch/Q/"
    lp.text =~ /page\/([0-9]+)\//i
    @last_page = $1.to_i
  else # no last page link, so this is the only page for this letter
    @last_page = 1
  end
  books_noko = parsed.xpath("//span[a][h4]") # Array of Nokogiri objects
  books_noko.search('.//h2').remove  # These are Date headings
  books_text =  books_noko.map {|b| b.text}
  return books_text
end

def next_line(lines)
  k = lines

  while lines.first.strip == '' || lines.first.length < 3  ## Because there may be a funny, non-std blank that doesn't strip
    lines.shift
  end
 return nil if lines == []
  nxt = lines.shift
  #puts ">" + nxt
  return nxt.strip
end

def process_entry(entry) # Generate Book from an entry
  book = Book.new
  lines=entry.split("\n")
  categories = []
  while lines.last == '' # remove trailing blank lines
    lines.pop
  end
  # TITLE
  next_line(lines) =~ /(.*)\s+(DB\w+)/  # Book title should be of form "Title DBxxxx"
  return nil unless $1   # doesn't match format for a book, ignore it
  book[:title] = $1.unicode_normalize
  book[:key] = $2  # The DBxxxx
  book[:title].sub!(/ *\/ *$/, '')  # get rid of trailing slash in title
  book[:title].sub!(/\. *$/,'') # get rid of trailing period
 # binding.pry
  # AUTHOR
  book[:author] = next_line(lines).unicode_normalize  # This should be only the author(s)
  if book[:author] =~ /^([\w,\.\-\' ]*)/ # Eliminate 2nd authors, parentheticals, etc.
    book[:author] = $1
  end
  if book[:author] =~ /(.*[a-z])\.$/  # Strip trailing . but not if it's part of an initial like F. Hope only author is on this line
    book[:author] = $1
  end

  # READING TIME
  reading_time = next_line(lines)
  if reading_time =~ /Reading time: (([0-9]+) hours)?([\., ]+?)? ?(([0-9]+) minutes)?/
    t = (($2 || 0).to_f + ($5 || 0).to_f/60.0)
	reading_time = ("%.1f" %t).to_f
  else
    reading_time = 0
  end
  book[:reading_time] = reading_time
  read_by = next_line(lines)
  if read_by =~ /Read by (.*)/
    book[:read_by] = $1
  else  # Read by is missing, so this must be the first (or only) category
    lines.unshift read_by  # put the category back into lines so we'll read it next
  end

  # BLURB
  if lines.last =~ /Download /  # Should always be there as last line
    lines.pop
  end
  book[:blurb] = lines.pop # Last line before Download link,

  # CATEGORIES
  lines.each do |line|
    book.add_category line if (line > '') and (line =~ /(production)|(National)|(NLS)/).nil?
  end
  return book
end

def get_resume_mark
  return(['A',1]) unless File.exist?('nls_bard_bookmark.txt')
  f = File.open('nls_bard_bookmark.txt', 'r')
  letter, page = f.readlines
  f.close
  letter = (letter || "A")[0]
  page = (page || 1).chomp.to_i
  return([letter, page])
end

def save_resume_mark(letter, page)
  f = File.open('nls_bard_bookmark.txt', 'w')
  f.puts(letter, page)
  f.close
  return
end

def iterate_pages(start_letter, start_num)
  initialize_nls_bard_chromium
  @last_page = start_num  # will be re-determined from next page read
  @test_limit = 999 # Pages per letter -
  @max_books_per_page = 9999
  letters = (start_letter..'Z').to_a
  letters.each do |letter|
    if letter == start_letter then
	  num = start_num
	else
	  num = 1
	end
		while (num <= @last_page) and (num <= @test_limit)
			save_resume_mark(letter, num)
			@book_number = 0
			base_url = "https://nlsbard.loc.gov/nlsbardprod/search/title/page/<page>/sort/s/srch/<letter>/local/0"
			page = get_page(letter,num, base_url)  # i.e. puts HTML into page; get_page returns nil if finished
			entries = process_page(page)
			puts "\n************************ PAGE #{letter}: #{num} of #{@last_page} ***********************"
			entries.each do |e|
			  @book_number += 1
			  break if @book_number > @max_books_per_page
			  book = process_entry(e)
			  if book # because if book is nil, there is no book to process!!
				book.get_rating
				@outfile.puts book.to_s
		#	binding.pry if book[:key] == 'DBF02660'
				@mybooks.insert_book(book)
				puts "#{book[:stars]} (#{book[:ratings]}): #{book[:title]} <#{book[:author]}>"
				sleep 1
			  end
			end
			num += 1
		end
		save_resume_mark("!",9999)
	end

end

def iterate_update_pages(days)
    initialize_nls_bard_chromium
	@last_page = 1
    num = 1  # Starting page number
	letter = '-' # Just a placeholder
	base_url =
	 # "https://nlsbard.loc.gov/nlsbardprod/search/recently_added/page/<page>/sort/s/local/0/day/#{days}/srch/recently_added/"
     # "https://nlsbard.loc.gov/nlsbardprod/search/recently_added/page/1/sort/s/srch/recently_added/local/0/day/#{days}/until/now/"
	 # The format of the 'select so many recent days' request isn't working, so will just say "recently added". However
	 # this is inadequate if it's been too long since running the query, as books will slip through the cracks!
	 "https://nlsbard.loc.gov/nlsbardprod/search/recently_added/page/<page>/sort/s/srch/recently_added/local/0"
	while (num <= @last_page)
		@book_number = 0
		page = get_page('', num, base_url)  # i.e. puts HTML into page; get_page returns nil if finished
		entries = process_page(page)
		puts "\n************************ PAGE #{letter}: #{num} of #{@last_page} ***********************"
		entries.each do |e|
		  @book_number += 1
		  book = process_entry(e)

		  if book # because if book is nil, there is no book to process!!
			if ! @mybooks.book_exists?(book)
				book.get_rating
				sleep 2
				book[:has_read] = false
				@outfile.puts book.to_s  # Optional
				@mybooks.insert_book(book)
				if @mybooks.is_interesting(book[:key])
				  book.display
				end
			else
			    @mybooks.update_book_categories(book)
				if book[:stars] == 0  # Just a one-time fix to get ratings of existing entries
				  existing_book = @mybooks.get_book(book[:key])
				  book[:stars] = existing_book[:stars]  # Fill these in
				  book[:ratings] = existing_book[:ratings]
				end
				@outfile.puts book.to_s
				puts "#{book[:stars]} (#{book[:ratings]}): #{book[:title]} <#{book[:author]}> <#{book[:categories]}>"
			end
		  end
		end
		num += 1
		# return if @book_number > 4
	end
end

def read_all
	letter, page = get_resume_mark
	if letter == "!"
	  raise "Entire catalog already read. Delete nls_bard_bookmark.txt and re-run if you want another pass."
	end
	@outfile = File.open("nls_bard_books.txt",'a') # append to existing file
	iterate_pages(letter, page)
end

def read_updates(days)
	@outfile = File.open("nls_bard_books_updates.txt",'a') # append to existing file
	iterate_update_pages(days)
end

def update_years # Try to find publication year for DB entries which don't have it
    missing = @books.filter(:year => 0)
	missing.each do |book|
	  if book[:blurb] =~ /\. +([0-9]{4})\./
	    year = $1.to_i
	    puts "Updating #{book[:key]} #{book[:title]} to #{year}"
		@mybooks.update_book_year(book[:key], year)
	  end
	end
end

#### NEED TO SIMPLIFY/COMBINE THESE SEARCH/LIST METHODS IF WE GO FURTHER
def list_books_w_matching_title(title)
    books = @mybooks.get_books_by_title(title)
	books.each {|book| puts "#{book[:key]} | #{book[:author]}, #{book[:title]}"}
end

def list_books_w_matching_author(author)
    books = @mybooks.get_books_by_author(author)
	books.each {|book| puts "#{book[:key]} | #{book[:author]}, #{book[:title]}"}
end

def list_books_by_filter(filter)
    if filter[:title] + filter[:author] + filter[:blurb] + filter[:key] == ''
		puts "No title, author, key, or blurb specified"
		return
	end
    books = @mybooks.get_by_hash(filter)
#	books.each {|book| puts "#{book[:key]} | #{book[:author]}, #{book[:title]}"}
	if books
	    if $verbose
			books.each do |book_hash|
				book = Book.new(book_hash) #{screen_output}"
				book.display(screen_output)  # Book needs to know how to format, for screen or a file
				puts ''
			end
		else
			books.each {|book| puts "#{book[:key]} | #{book[:author]}. #{book[:title]}"}
		end
	else
		puts "*** NO MATCHING BOOKS FOUND ***"
	end
end

def download(key)
	download_url = "https://nlsbard.loc.gov/nlsbardprod/download/book/srch/#{key}"#
	initialize_nls_bard_chromium
	@nls_driver.navigate.to(download_url)
    book = @mybooks.get_book(key)
	binding.pry if $debug
	if book
	  @books.filter(key: book[:key]).update(has_read: true, date_downloaded: Date::today) # should move to nls_bard_sequel
	  @mybooks.wish_delete(key: book[:key])  # Remove from the wishlist -- not working!
	end
end

def initialize_database
  @mybooks = BookDatabase.new
  @books = @mybooks.books
end

def initialize_nls_bard_chromium
  return if @nls_driver
  @nls_driver = init_chromium_driver # sets up @nls_driver as the chromium driver for NLS BARD)
 login # (to NLS BARD, leaves us at the home page)

end

def wrap_up
  @nls_driver.quit if @nls_driver
  @outfile.close if @outfile
  $stdout = @original_stdout
end

def screen_output
  return $stdout == @original_stdout
end

def dump_table_yaml(filename,table)
  out = File.open(filename,'w')
  table.each do |item|
    out.write YAML.dump(item)
  end
  rescue
    puts "****** FILE ERROR DUMPING TO #{filename} *********"
	raise
  ensure
    out.close unless out.nil?
end

def backup_tables
  puts "Dumping database"
  dump_table_yaml('books.yaml',@books)
  dump_table_yaml('cats.yaml',@mybooks.cats)
  dump_table_yaml('wish.yaml',@mybooks.wish)
  dump_table_yaml('cat_book.yaml',@mybooks.cat_book)
end

def rating_update_needed(book) # For now, this is adjusted by changing the code! ******************
  return false if book[:language] != 'English'
#  interesting = @mybooks.is_interesting(book[:key], :minimum_stars=>0, :minimum_ratings=>0 )
  update_interval = 60 # days since last check
  max_ratings_needed = 1000000  # Can use lower number once all have been rated once
  time_for_update = (book[:stars_date].nil?) || ((Date.today - book[:stars_date]).to_i >= update_interval)
  rating_criteria = book[:ratings].nil? || book[:ratings] < max_ratings_needed
  return time_for_update && rating_criteria

#  xtitle = book[:title] || ''
#  gtitle = book[:goodreads_title] || ''
#  puts "#{book[:title]} | #{book[:goodreads_title][0..20]} | #{n}"
#  return ( $manual_update && (book[:goodreads_title] == 'no match xxx')) # !!!! This lets us visit ONLY "no match" titles if on manual update
#  return xtitle =~ /A prayer for the city/i  # Use this line to check only certain title
# return (gtitle == 'no match xxx')  # Use this line only to update ALL records with "no match"

end

def update_ratings
  i = 0
#  books_to_update = @mybooks.books_with_desired_category.order(:key) # Use this one to update only the desired-category books
#  books_to_update = @mybooks.books.order(:title)  ### Update all books
  books_to_update = @mybooks.books_with_desired_category.order(:key)  ### Update books of desired categories
  books_to_update.each do |bookhash|
	i = i+1
	next if i < 17000
	book = Book.new(bookhash)
	# Time to update rating?
	if rating_update_needed(book)
	  old_stars = book[:stars]
	  old_ratings = book[:ratings] || 0
	  book.get_rating
	  stars = book[:stars]
	  ratings = book[:ratings]|| 0
	  if ratings < old_ratings then
		  puts "** Warning: number of ratings has decreased on #{book[:key]} #{book[:title]}"
	  end
	  puts "#{i}: (#{old_stars}, #{old_ratings}) -> (#{stars}, #{ratings}) | #{book[:key]} | #{book[:title]}"
	  @mybooks.update_book_rating(book)
	  sleep(1)
	  sleep(10) if i %20 == 0  # pause after every 20th update to make Goodreads happy
	end
#	binding.pry
   end
end

def zip_backups
  puts "Zipping backup files"
  folder='.'
  if File.exists?('nls_bard_database.zip')
    File.delete('nls_bard_database.zip')
  end
  files = ['books', 'cats', 'wish', 'cat_book']
  Zip::File.open('nls_bard_database.zip', Zip::File::CREATE) do |zipfile|
    files.each {|f| zipfile.add(f+'.yaml', File.join(folder, f+'.yaml'))}
  end
  files.each {|f| File.delete(f+'.yaml')}
  rescue
    puts "*********** ERROR WHILE ZIPPING FILES OR DELETING TEMP FILES *********"
	raise
end

def handle_command(command_line)
#
	if command_line.is_a? String
	 args = command_line.split(' ')
	else
	 args = command_line # already an array, probably ARGV
	end

	options = Optparse.parse(args) # Parse, label the options

	# Runtime options
	$verbose = options.verbose
	$debug = options.debug
	$manual_update = options.manual_update

	# Filters
	filters = {}
	filters[:title] = options.title
	filters[:author] = options.author
	filters[:blurb] = options.blurb
	filters[:key] = options.key.upcase
	puts 'filters loaded' if $debug
	binding.pry if $debug

	if options.getnew > 0
		puts "getting books added in past #{options.getnew} days"
		read_updates(options.getnew)
	end

	if options.output > ''
#	    puts "Option output #{options.output}, @original_stdout = #{@original_stdout}"
		puts "Redirecting to #{options.output}"
		$stdout.reopen(options.output,"w")
#		pp $stdout, @original_stdout, ($stdout == @original_stdout), ($stdout === @original_stdout)
	end

	if options.find && filters.count > 0
		list_books_by_filter(filters)
	end

	if options.wish
		author = filters[:author]
		if filters[:title] > ''

			if author =~ /(.*?),/   # Use only part before comma, i.e. first name
			  filters[:author] = $1
			else
			  filters[:author] = author.split.last  # Last name only
 		    end
			@mybooks.insert_wish(filters)
		else  # No auth/title given, so just list
			@mybooks.list_wish
			@mybooks.check_for_wishlist_matches
		end
	end

	if options.mark != []
		options.mark.map! {|key| key.upcase}
		options.mark.each do |key|
		end
		selected = @books.where(:key=>options.mark)
		selected.update(bookmarked: true)
		puts "Bookmarked:"
		selected.each {|book| puts "\t#{book[:key]} | #{book[:title]}"}
	end

	if options.unmark != []
		options.unmark.map! {|key| key.upcase}
		puts "Removing bookmark from:"
		if options.unmark.first.downcase == 'all' then
			selected = @books.where(:bookmarked=>true)
			puts "--ALL--"
		else
			selected = @books.where(:key=>options.unmark)
			selected.each {|book| puts "\t#{book[:key]} | #{book[:title]}"}
		end
		selected.update(bookmarked: false)
	end

	if options.marked
		selected = @books.where(:bookmarked)
		puts "Bookmarked:"
		selected.each {|book| puts "\t#{book[:key]} | #{book[:title]}"}
	end

	if options.backup
		backup_tables
		zip_backups
	end

	if options.download != []
		puts "Downloading #{options.download}"
		options.download.each {|key| download(key)}
	end

	if options.update_ratings
	    update_ratings
    end

	binding.pry if $debug

	ensure
	  $stdout = @original_stdout
end

def normalize
	i = 0
	@books.each do |b|
	   normalized_author = b[:author].unicode_normalize
	   normalized_title = b[:title].unicode_normalize
       #puts "#{i.to_s}\tb[:title]"
       if (normalized_author != b[:author]) || (normalized_title != b[:title])
		   b[:author] = normalized_author
		   b[:title]  = normalized_title
		   @mybooks.update_book_author_title(b)
		   i = i+1
		   puts i
	   end
	end
end

# main program
@original_stdout = $stdout.clone
#puts "Original = #{$stdout}"
@nls_driver = nil
@logged_in = false
initialize_database
args = ARGV
Reline::HISTORY << (args.join(' '))

while (args != [])
   handle_command args
   puts
   puts "Enter command or 'quit'"
#   command_line = gets.chomp
   command_line = Readline.readline('> ', true)
   args = command_line.shellsplit
   exit if args == [] || args[0] =~ /(exit)|(end)|(quit)/i
end

wrap_up




#read_all # Read sorted-by-title-a-z all entries
#read_updates(30)
#update_years











# Log in
#auth = {:username=>"mjblyth@gmail.com", :password=>"derbywarin5", :loginid = "mjblyth@gmail.com"}
#url = "https://nlsbard.loc.gov:443/nlsbardprod/login/mainpage/NLS"
#page = HTTParty.get(url, :basic_auth=>auth)
#
#https://nlsbard.loc.gov/nlsbardprod/search/title/page/1/sort/s/srch/A/local/0
