require 'selenium-webdriver'
require 'bundler/setup'
# ****************************************************************************
# If you get an error about chromeddriver being outdated or incompatible, then go to
# https://chromedriver.chromium.org/downloads
# and download the version that matches the current version of Chrome. Hopefully there will
# always be a compatible one!
# Extract the file chromedriver.exe to D:\Program Files (x86)\chromedriver\
# ****************************************************************************1
require 'nokogiri'
# require 'debug'
require 'httparty'
require 'date'
require './goodreads' # Allows us to access the ratings on Goodreads
require './nls_bard_sequel' # interface to database
require_relative 'bard_session_manager'
require './nls_book_class'
require './nls_bard_command_line_options'
require 'shellwords' # turns string into command-line-like args
require 'csv'
require 'zip'
require 'nameable'
require 'reline'
require 'dotenv/load'

@book_number = 0

# Helper function to perform BARD website operations with retry logic
def with_bard_retry(operation_name, max_retries: 3)
  retry_count = 0
  begin
    yield
  rescue Selenium::WebDriver::Error::TimeoutError, 
         Selenium::WebDriver::Error::WebDriverError,
         Net::OpenTimeout, Net::ReadTimeout, 
         Errno::ECONNRESET, SocketError => e
    retry_count += 1
    if retry_count <= max_retries
      puts "Network error during #{operation_name} (attempt #{retry_count}/#{max_retries}): #{e.class.name}"
      sleep(2 * retry_count) # Exponential backoff: 2, 4, 6 seconds
      retry
    else
      puts "\n" + "="*60
      puts "FATAL: Failed to #{operation_name} after #{max_retries} attempts"
      puts "Error: #{e.message}"
      puts "BARD website connection is critical and scraping cannot continue."
      puts "Please check your network connection and try again later."
      puts "="*60
      exit(1)
    end
  rescue => e
    puts "\n" + "="*60
    puts "FATAL: Unexpected error during #{operation_name}"
    puts "Error: #{e.class.name} - #{e.message}"
    puts "Scraping stopped to prevent data loss."
    puts "="*60
    exit(1)
  end
end

def download(key)
  # Validate the key format case-insensitively.
  return puts "Invalid key format: '#{key}'. Not a standard book ID." unless key =~ /\A[A-Z]{1,3}[0-9]+\z/i

  key.upcase! # Convert to uppercase for consistency with BARD URLs and internal usage.

  BardSessionManager.initialize_nls_bard_chromium
  driver = BardSessionManager.nls_driver
  wait = Selenium::WebDriver::Wait.new(timeout: 15)

  begin
    # Navigate to the book's detail page on the new BARD site, per README.md
    book_url = "https://nlsbard.loc.gov/bard2-web/search/#{key}/"
    driver.navigate.to book_url

    # Find the download link directly on the page.
    download_link = wait.until do
      driver.find_element(:xpath, "//a[starts-with(@href, '/bard2-web/download/#{key}') and contains(., 'Download')]")
    end

    book_title = download_link.text.sub('Download', '').strip
    puts "Initiating download for: #{book_title} (#{key})"
    download_link.click

    puts 'Download initiated. Be sure to wait for it to complete before exiting the app.'
    update_book_records(key, book_title)
  rescue Selenium::WebDriver::Error::TimeoutError
    puts "Timeout error: Could not find download elements for #{key}."
    puts "Current URL at timeout: #{driver.current_url}"
  rescue Selenium::WebDriver::Error::NoSuchElementError => e
    puts "Element not found error: The page structure for #{key} may have changed or the book is not available. Error: #{e.message}"
  rescue StandardError => e
    puts "An unexpected error occurred during download of #{key}: #{e.message}"
    puts e.backtrace.join("\n")
  end
end

# Process raw HTML and return array of plain text entries
def process_page(page_content)
  parsed_page = Nokogiri::HTML(page_content)
  # The new BARD site wraps each book in a div with the class 'item-details'.
  # We return the Nokogiri elements themselves for more robust parsing in process_entry.
  # The logic to find the "Last Page" is no longer needed as we iterate by clicking the "Next page" link.
  parsed_page.css('div.item-details')
end

def next_line(lines)
  k = lines

  while lines.first.strip == '' || lines.first.length < 3 ## Because there may be a funny, non-std blank that doesn't strip
    lines.shift
  end
  return nil if lines == []

  nxt = lines.shift
  # puts ">" + nxt
  nxt.strip
end

# Generate Book from a Nokogiri element
def process_entry(book_element)
  book_hash = {}

  # The book's key is the ID of the container div
  book_hash[:key] = book_element['id']
  return nil unless book_hash[:key]

  # Exclude periodicals, which have a non-standard key format (e.g., 'DBpsychology-today_2025-07')
  return nil unless book_hash[:key] =~ /\A[A-Z]{1,3}[0-9]+\z/

  # Extract details using CSS selectors, with &. to prevent errors on missing elements
  raw_title = book_element.at_css('h4.item-link a span')&.text&.strip || ''
  book_hash[:title] = raw_title.sub(/\s+#{book_hash[:key]}$/, '').strip
  book_hash[:author] =
    book_element.at_css('p[data-testid="detail-value-p-author"]')&.text&.sub('Author:', '')&.strip || ''
  book_hash[:read_by] =
    book_element.at_css('p[data-testid="detail-value-p-narrators-label"]')&.text&.sub('Read by:', '')&.strip || ''
  book_hash[:categories] =
    book_element.at_css('p[data-testid="detail-value-p-subjects"]')&.text&.sub('Subjects:', '')&.strip || ''
  book_hash[:blurb] = book_element.at_css('p.annotation')&.text&.strip || ''

  # Parse reading time
  time_str = book_element.at_css('p[data-testid="detail-value-p-reading-time"]')&.text
  book_hash[:reading_time] = parse_reading_time(time_str)

  Book.new(book_hash)
end

def parse_reading_time(time_str)
  return 0.0 unless time_str

  hours = time_str.match(/(\d+)\s+hour/)&.captures&.first.to_i
  minutes = time_str.match(/(\d+)\s+minute/)&.captures&.first.to_i

  (hours + (minutes / 60.0)).round(1)
end

def get_resume_mark
  return(['A', 1]) unless File.exist?('output/nls_bard_bookmark.txt')

  f = File.open('output/nls_bard_bookmark.txt', 'r')
  letter, page = f.readlines
  f.close
  letter = (letter || 'A')[0]
  page = (page || 1).chomp.to_i
  [letter, page]
end

def save_resume_mark(letter, page)
  f = File.open('output/nls_bard_bookmark.txt', 'w')
  f.puts(letter, page)
  f.close
  nil
end

def iterate_pages(start_letter)
  BardSessionManager.initialize_nls_bard_chromium
  driver = BardSessionManager.nls_driver
  @processed_keys_this_session = Set.new # Track keys processed in this run to handle duplicates across pages.

  letters = (start_letter..'Z').to_a
  letters.each do |letter|
    # For a full A-Z scrape, we perform a search for each letter.
    # The new site's search URL for titles starting with a letter:
    initial_url = "https://nlsbard.loc.gov/bard2-web/search/title/#{letter}/"
    puts "\n--- Starting scrape for letter '#{letter}' ---"
    
    with_bard_retry("navigate to letter #{letter} page") do
      driver.navigate.to initial_url
    end

    page_number = 1
    loop do
      save_resume_mark(letter, page_number)
      puts "\n--- Processing Page #{page_number} for letter '#{letter}' ---"

      sleep 1 # Give page time to load
      
      page_content = with_bard_retry("get page source for letter #{letter}, page #{page_number}") do
        driver.page_source
      end
      
      entries = process_page(page_content)

      entries.each { |entry| process_book_entry(entry) }
      # Find and click the "Next page" link to continue.
      begin
        next_page_link = driver.find_element(:xpath, "//a[span[contains(text(), 'Next page')]]")
        puts "Navigating to next page for letter '#{letter}'..."
        with_bard_retry("click next page link for letter #{letter}") do
          next_page_link.click
        end
        page_number += 1
      rescue Selenium::WebDriver::Error::NoSuchElementError
        puts "No more pages for letter '#{letter}'. Moving to next letter."
        break # Exit the inner loop for this letter
      end
    end
  end
  save_resume_mark('!', 9999) # Mark the A-Z scrape as complete
end

def iterate_update_pages
  BardSessionManager.initialize_nls_bard_chromium
  @processed_keys_this_session = Set.new # Track keys processed in this run to handle duplicates across pages.

  # Navigate to the initial "recently added" page.
  # Gets whatever the site considers "new" books
  initial_url = 'https://nlsbard.loc.gov/bard2-web/search/results/recently-added/?language=en&format=all&type=book'
  
  with_bard_retry("navigate to recently added page") do
    BardSessionManager.nls_driver.navigate.to initial_url
  end

  page_number = 1
  loop do
    puts "\n--- Processing Page #{page_number} ---"

    # Give the page a moment to load, especially after a click
    sleep 1
    
    page_content = with_bard_retry("get page source for page #{page_number}") do
      BardSessionManager.nls_driver.page_source
    end

    # NOTE: process_page and process_entry will need to be adapted for the new site's HTML structure.
    entries = process_page(page_content)

    entries.each { |entry| process_book_entry(entry) }

    # Find and click the "Next page" link to continue.
    begin
      # The link text has a comment inside the span, so a partial match is better. e.g. <span>Next page<!-- --> </span>
      next_page_link = BardSessionManager.nls_driver.find_element(:xpath, "//a[span[contains(text(), 'Next page')]]")
      puts 'Navigating to next page...'
      with_bard_retry("click next page link") do
        next_page_link.click
      end
      page_number += 1
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # This is the expected way to exit the loop: no "Next page" link was found.
      puts 'No more pages to process. Finished.'
      break
    end
  end
end

private

def process_book_entry(entry)
  book = process_entry(entry) # entry is now a Nokogiri element
  return unless book # Skip if entry couldn't be parsed into a book

  # Prevent processing the same book twice in one session if it appears on multiple pages.
  # This can happen on the "recently added" pages.
  return if @processed_keys_this_session&.include?(book[:key])

  # Define patterns for non-English languages in categories
  non_english_patterns = [
    /Spanish Language/i,
    /French Language/i,
    /German Language/i,
    /Chinese Language/i,
    /Japanese Language/i,
    /Russian Language/i,
    /Arabic Language/i,
    /Portuguese Language/i,
    /Italian Language/i,
    /Korean Language/i,
    /Vietnamese Language/i,
    /Hindi Language/i,
    /Urdu Language/i,
    /Tagalog Language/i,
    /Farsi Language/i,
    /Persian Language/i,
    /Hebrew Language/i,
    /Yiddish Language/i,
    /Latin Language/i,
    /Greek Language/i,
    /Multilingual/i
  ]

  # Check if any non-English language pattern is present in categories
  if non_english_patterns.any? { |pattern| book[:categories] =~ pattern }
    puts "Skipping non-English book: #{book[:title]} (#{book[:key]}) - Language detected in categories."
    return
  end

  # We only want to process and add books that are new to our database.
  # If a book already exists, we skip it to avoid unnecessary processing
  # like fetching ratings or performing database updates. The `insert_book` method
  # uses an "INSERT ... ON CONFLICT DO NOTHING" as a final safety net in case
  # this check fails, preventing a crash and leaving the existing record untouched.
  add_new_book(book) unless @mybooks.book_exists?(book[:key])

  # Add the key to the set of processed keys for this session.
  @processed_keys_this_session&.add(book[:key])
end

def add_new_book(book)
  puts "New book found: #{book[:title]}"
  book.get_rating
  sleep 2 # Be respectful to Goodreads API
  book[:has_read] = false
  @outfile.puts book.to_s if @outfile
  @mybooks.insert_book(book)
  book.display if @mybooks.is_interesting(book[:key])
end

def update_existing_book(book)
  puts "Updating existing book: #{book[:title]}" if $verbose
  @mybooks.update_book_categories(book)
  existing_book = @mybooks.get_book(book[:key])

  # If the existing book has no rating, try to fetch it now.
  return unless existing_book && (existing_book[:stars].nil? || existing_book[:stars].zero?)

  book.get_rating
  sleep 2
  @mybooks.update_book_rating(book)
  puts "-> Fetched rating: #{book[:stars]} stars." if $verbose
end

def read_all
  letter, _page = get_resume_mark # page is no longer used for navigation
  if letter == '!'
    raise 'Entire catalog already read. Delete nls_bard_bookmark.txt and re-run if you want another pass.'
  end

  @outfile = File.open('output/nls_bard_books.txt', 'a') # append to existing file
  iterate_pages(letter)
end

def read_updates
  @outfile = File.open('output/nls_bard_books_updates.txt', 'a') # append to existing file
  iterate_update_pages
end

def update_years # Try to find publication year for DB entries which don't have it
  missing = @books.filter(year: 0)
  missing.each do |book|
    next unless book[:blurb] =~ /\. +([0-9]{4})\./

    year = Regexp.last_match(1).to_i
    puts "Updating #{book[:key]} #{book[:title]} to #{year}"
    @mybooks.update_book_year(book[:key], year)
  end
end

def list_books_by_filter(filter, options)
  if filter[:title] + filter[:author] + filter[:blurb] + filter[:key] == ''
    puts 'No title, author, key, or blurb specified'
    return
  end

  books = if (filter[:key] || '') > ''
            # If a specific key is provided, perform a direct lookup.
            book = @mybooks.get_book(filter[:key])
            book ? [book] : [] # Wrap single result in array, or empty array if not found
          elsif options.fuzzy
            # Otherwise, perform a fuzzy or standard search.
            puts 'Performing fuzzy search...'
            @mybooks.get_by_hash_fuzzy(filter)
          else
            @mybooks.get_by_hash(filter)
          end

  #	books.each {|book| puts "#{book[:key]} | #{book[:author]}, #{book[:title]}"}
  if books && books.any?
    if $verbose
      books.each do |book_hash|
        book = Book.new(book_hash) # {screen_output}"
        book.display(screen_output) # Book needs to know how to format, for screen or a file
        puts ''
      end
    else
      books.each { |book| puts "#{book[:key]} | #{book[:author]}. #{book[:title]}" }
    end
  else
    puts '*** NO MATCHING BOOKS FOUND ***'
  end
end

def update_book_records(key, title)
  mark_book_as_read(key, "Updated records for book: #{title} (#{key})")
end

def update_author_read_count(book)
  # Parse author names and increment their has_read count
  return if book[:author].nil? || book[:author].strip.empty?
  
  require_relative 'name_parse'
  
  # Split multiple authors by semicolon
  author_list = book[:author].split(';').map(&:strip).reject(&:empty?)
  
  author_list.each do |author_name|
    parsed = parse_author_name(author_name)
    next if parsed[:last].empty?
    
    # Increment the author's has_read count using direct database access
    rows_updated = @mybooks.DB[:authors].where(
      last_name: parsed[:last],
      first_name: parsed[:first],
      middle_name: parsed[:middle]
    ).update(has_read: Sequel.expr(:has_read) + 1)
    
    if rows_updated > 0
      puts "  Updated read count for author: #{parsed[:first]} #{parsed[:middle]} #{parsed[:last]}"
    end
  end
end

def parse_author_name(name)
  return {last: '', first: '', middle: ''} if name.nil? || name.strip.empty?
  
  name = name.strip
  
  # Handle corporate/organizational authors
  if name.include?('(') || name.include?('Society') || name.include?('Association') || 
     name.include?('Institute') || name.include?('Organization') || name.include?('Inc.') ||
     name.include?('Corp.') || name.include?('Company') || name.include?('Press')
    return {last: name[0..19], first: '', middle: ''}
  end
  
  parsed = name_parse(name)
  {
    last: (parsed[:last] || '')[0..19],
    first: (parsed[:first] || '')[0..19], 
    middle: (parsed[:middle] || '')[0..19]
  }
end

def mark_book_as_read(key, success_message = nil)
  # Validate the key format case-insensitively.
  return puts "Invalid key format: '#{key}'. Not a standard book ID." unless key =~ /\A[A-Z]{1,3}[0-9]+\z/i

  key.upcase! # Convert to uppercase for consistency

  book = @mybooks.get_book(key)
  if book
    @books.filter(key: book[:key]).update(has_read: true, date_downloaded: Date.today)
    @mybooks.wish_mark_downloaded(key: book[:key])
    update_author_read_count(book)
    
    # Sync to Google Sheets if enabled - mark as read
    @mybooks.mark_book_read_in_sheets(book[:title], book[:author])
    
    puts success_message || "Marked as downloaded: #{book[:title]} (#{key})"
  else
    puts "Book with key #{key} not found in the database."
  end
end

def mark_as_downloaded(key)
  mark_book_as_read(key)
end

def initialize_database
  @mybooks = BookDatabase.new
  @books = @mybooks.books
end

def wrap_up
  @nls_driver.quit if @nls_driver
  @outfile.close if @outfile
  $stdout = @original_stdout
end

def screen_output
  $stdout == @original_stdout
end

# def dump_table_yaml(filename, table)
#   out = File.open(filename, 'w')
#   table.each do |item|
#     out.write YAML.dump(item)
#   end
# rescue StandardError
#   puts "****** FILE ERROR DUMPING TO #{filename} *********"
#   raise
# ensure
#   out.close unless out.nil?
# end

def backup_tables
  puts 'Dumping database'
  @mybooks.dump_database
  exit

  # dump_table_yaml('books.yaml', @books)
  # dump_table_yaml('cats.yaml', @mybooks.cats)
  # dump_table_yaml('wish.yaml', @mybooks.wish)
  # dump_table_yaml('cat_book.yaml', @mybooks.cat_book)
end

def rating_update_needed(book)
  return false if book[:language] != 'English'

  # If the book has never been rated, it always needs an update.
  return true if book[:stars_date].nil? || book[:ratings].nil?

  days_since_last_check = (Date.today - book[:stars_date]).to_i
  ratings_count = book[:ratings]

  # For books with few ratings, check more frequently to get a stable rating.
  return days_since_last_check >= 60 if ratings_count < 100

  # For books with many ratings, check much less frequently.
  days_since_last_check >= 365
end

def update_ratings
  i = 0
  #  books_to_update = @mybooks.books_with_desired_category.order(:key) # Use this one to update only the desired-category books
  #  books_to_update = @mybooks.books.order(:title)  ### Update all books
  books_to_update = @mybooks.books_with_desired_category.order(:key) # Update books of desired categories
  books_to_update.each do |bookhash|
    i += 1

    book = Book.new(bookhash)
    # Time to update rating?
    next unless rating_update_needed(book)

    old_stars = book[:stars]
    old_ratings = book[:ratings] || 0
    book.get_rating
    stars = book[:stars]
    ratings = book[:ratings] || 0
    puts "** Warning: number of ratings has decreased on #{book[:key]} #{book[:title]}" if ratings < old_ratings
    puts "#{i}: (#{old_stars}, #{old_ratings}) -> (#{stars}, #{ratings}) | #{book[:key]} | #{book[:title]}"
    @mybooks.update_book_rating(book)
    sleep(1)
    sleep(10) if i % 20 == 0 # pause after every 20th update to make Goodreads happy
  end
end

def zip_backups
  puts 'Zipping backup files'
  folder = '.'
  File.delete('nls_bard_database.zip') if File.exist?('nls_bard_database.zip')
  files = %w[books cats wish cat_book]
  Zip::File.open('nls_bard_database.zip', Zip::File::CREATE) do |zipfile|
    files.each { |f| zipfile.add(f + '.yaml', File.join(folder, f + '.yaml')) }
  end
  files.each { |f| File.delete(f + '.yaml') }
rescue StandardError
  puts '*********** ERROR WHILE ZIPPING FILES OR DELETING TEMP FILES *********'
  raise
end

def handle_command(command_line)
  #
  args = if command_line.is_a? String
           command_line.split(' ')
         else
           command_line # already an array, probably ARGV
         end

  options = Optparse.parse(args) # Parse, label the options
  
  # Return early if parsing failed (invalid command)
  return if options.nil?

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

  if options.getnew
    puts "Getting new books from site"
    read_updates
    
    # Get books added today for wishlist checking and Google Sheets sync
    today_books = @mybooks.books.where(date_added: Date.today).all
    
    # Enable Google Sheets sync for post-session processing
    @mybooks.enable_sheets_sync
    
    if @mybooks.sheets_enabled?
      # Perform full bidirectional sync with Google Sheets
      @mybooks.sync_after_book_session(options.check_all_wishlist ? nil : today_books)
    else
      # Fallback to local-only wishlist matching if sheets not available
      if options.check_all_wishlist
        @mybooks.check_for_wishlist_matches
      else
        @mybooks.check_for_wishlist_matches(today_books) if today_books.any?
      end
    end
    
    # Sync interesting books to Google Sheets after scraping (without terminal output)
    @mybooks.sync_interesting_books_to_sheets
  end

  if options.output > ''
    #	    puts "Option output #{options.output}, @original_stdout = #{@original_stdout}"
    puts "Redirecting to #{options.output}"
    $stdout.reopen(options.output, 'w')
    #		pp $stdout, @original_stdout, ($stdout == @original_stdout), ($stdout === @original_stdout)
  end

  list_books_by_filter(filters, options) if options.find && filters.count > 0

  if options.wish
    author = filters[:author]
    if filters[:title] > ''
      # Enable Google Sheets sync for wishlist operations
      @mybooks.enable_sheets_sync

      # Preserve the full author name as entered
      filters[:author] = author
      @mybooks.insert_wish(filters)
    else # No auth/title given, so do full bidirectional sync
      # Enable Google Sheets sync for bidirectional sync
      @mybooks.enable_sheets_sync
      
      if @mybooks.sheets_enabled?
        # Do full bidirectional sync: read sheet → add new items → find matches → write back
        @mybooks.sync_after_book_session
        # Display the wishlist on terminal after sync
        puts "📋 Displaying wishlist..."
        @mybooks.list_wish
        # Display formatted matches
        @mybooks.check_for_wishlist_matches
      else
        # Fallback to local display if sheets not available
        @mybooks.list_wish
        @mybooks.check_for_wishlist_matches
      end
    end
  end

  @mybooks.wish_remove_by_title(options.wish_remove) if options.wish_remove > ''

  if options.mark != []
    options.mark.map! { |key| key.upcase }
    options.mark.each do |key|
    end
    selected = @books.where(key: options.mark)
    selected.update(bookmarked: true)
    puts 'Bookmarked:'
    selected.each { |book| puts "\t#{book[:key]} | #{book[:title]}" }
  end

  if options.unmark != []
    options.unmark.map! { |key| key.upcase }
    puts 'Removing bookmark from:'
    if options.unmark.first.downcase == 'all'
      selected = @books.where(bookmarked: true)
      puts '--ALL--'
    else
      selected = @books.where(key: options.unmark)
      selected.each { |book| puts "\t#{book[:key]} | #{book[:title]}" }
    end
    selected.update(bookmarked: false)
  end

  if options.marked
    selected = @books.where(:bookmarked)
    puts 'Bookmarked:'
    selected.each { |book| puts "\t#{book[:key]} | #{book[:title]}" }
  end

  if options.interesting
    puts "Finding interesting books with criteria:"
    puts "  Minimum stars: #{options.min_stars}"
    puts "  Minimum ratings: #{options.min_ratings}"
    puts "  Minimum year: #{options.min_year == 0 ? 'any' : options.min_year}"
    puts ""
    
    interesting_books = @mybooks.find_interesting_books(
      minimum_year: options.min_year,
      minimum_stars: options.min_stars,
      minimum_ratings: options.min_ratings
    ).all
    
    if interesting_books.any?
      puts "Found #{interesting_books.count} interesting book#{'s' if interesting_books.count != 1}:"
      puts ""
      
      # Sort by stars ascending
      interesting_books.sort_by! { |book| book[:stars] || 0 }
      
      # Group by first category
      books_by_category = interesting_books.group_by do |book|
        # Extract first category from categories string
        categories = book[:categories] || ""
        first_category = categories.split(/[,;]/).first&.strip || "Uncategorized"
        first_category
      end
      
      # Display grouped by category
      books_by_category.sort.each do |category, books|
        puts "=== #{category} ==="
        books.each do |book|
          book_obj = Book.new(book)
          if options.verbose
            book_obj.display
            puts ""
          else
            # Format key in 9-wide fixed field
            key_field = "%-9s" % (book[:key] || "")
            
            # Truncate title at 80 characters and colorize light blue
            title = book[:title] || ""
            truncated_title = title.length > 80 ? title[0..76] + "..." : title
            colored_title = "\033[96m#{truncated_title}\033[0m"  # Bright cyan color
            
            # Check if I have read books by this author (has_read > 0)
            author_indicator = @mybooks.has_read_author?(book[:author]) ? "\033[92mA\033[0m " : "  "
            
            puts "  #{author_indicator}#{key_field} | #{colored_title} by #{book[:author]} | ⭐ #{book[:stars]} (#{book[:ratings]} ratings)"
          end
        end
        puts ""
      end
    else
      puts "No books found matching the interesting criteria."
      puts "Try lowering the minimum stars or ratings, or check if you have desired categories set."
    end
    
    # Sync interesting books to Google Sheets after displaying
    @mybooks.enable_sheets_sync
    @mybooks.sync_interesting_books_to_sheets(
      min_stars: options.min_stars,
      min_ratings: options.min_ratings,
      min_year: options.min_year
    )
  end

  if options.backup
    backup_tables
    zip_backups
  end

  if options.sync_sheets
    puts "Syncing wishlist with Google Sheets..."
    @mybooks.enable_sheets_sync
    @mybooks.sync_full_wishlist_to_sheets
  end

  if options.test_add
    @mybooks.test_add_book(
      title: options.title,
      author: options.author, 
      key: options.key,
      date_added: options.test_date
    )
  end

  if options.test_delete
    @mybooks.test_delete_book(key: options.key)
  end

  if options.download != []
    puts "Downloading #{options.download}"
    options.download.each { |key| download(key) }
  end

  if options.mark_downloaded != []
    puts "Marking as downloaded: #{options.mark_downloaded}"
    options.mark_downloaded.each { |key| mark_as_downloaded(key) }
  end

  update_ratings if options.update_ratings
ensure
  $stdout = @original_stdout
end

def normalize
  i = 0
  @books.each do |b|
    normalized_author = b[:author].unicode_normalize
    normalized_title = b[:title].unicode_normalize
    # puts "#{i.to_s}\tb[:title]"
    next unless (normalized_author != b[:author]) || (normalized_title != b[:title])

    b[:author] = normalized_author
    b[:title] = normalized_title
    @mybooks.update_book_author_title(b)
    i += 1
    puts i
  end
end

# main program
if ARGV[0] == 'test'
  puts 'Starting download test...'
  initialize_database
  download('db35123')
  puts 'Download test completed.'
end

@original_stdout = $stdout.clone
# puts "Original = #{$stdout}"
@nls_driver = nil
@logged_in = false
initialize_database

# Handle initial command-line arguments if they exist
unless ARGV.empty?
  Reline::HISTORY << ARGV.join(' ')
  downloading = ARGV.include?('-d')
  handle_command(ARGV)
  # Exit if 'exit' was a command-line argument and we weren't downloading
  if ARGV.include?('exit') && !downloading
    wrap_up
    exit
  end
end

# Enter the interactive command loop (REPL)
loop do
  puts
  puts "Enter command or 'quit'"
  command_line = Reline.readline('> ', true)
  break if command_line.nil? # Handle Ctrl-D for EOF

  args = command_line.shellsplit
  break if args.empty? || args[0] =~ /(exit)|(end)|(quit)/i

  Reline::HISTORY << command_line
  
  begin
    handle_command(args)
  rescue => e
    puts "❌ Error executing command: #{e.message}"
    puts "Use -h or --help to see available options"
  end
end

wrap_up
