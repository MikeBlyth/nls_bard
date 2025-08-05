require 'sequel'
require_relative 'name_parse'

class BookDatabase
  attr_accessor :DB, :books, :cats, :wish, :cat_book, :columns

  # A set of common, non-descriptive words to ignore during fuzzy searches.
  STOP_WORDS = Set.new(%w[a an and are as at be but by for if in into is it no not of on or such that the their then
                          there these they this to was will with])

  def initialize
    user = ENV.fetch('POSTGRES_USER', 'mike')
    password = ENV.fetch('POSTGRES_PASSWORD')
    host = ENV.fetch('POSTGRES_HOST', 'db')
    db_name = ENV.fetch('POSTGRES_DB', 'nlsbard')

    @DB = Sequel.connect("postgres://#{user}:#{password}@#{host}/#{db_name}")
    # Referenced as @mybooks.DB in nls_bard.rb
    @books = @DB[:books] # Tables ...  									# @mybooks.books
    @cats = @DB[:cats]
    @wish = @DB[:wishlist]
    @cat_book = @DB[:cat_book]
    @columns = @books.columns # Book columns
    setup_database_indexes
  end

  def book_exists?(key)
    # Extract the key string whether a Book object or a String is passed.
    book_key_val = key.is_a?(Book) ? key[:key] : key
    # A nil or empty key cannot exist in the database.
    return false if book_key_val.nil? || book_key_val.strip.empty?

    !@books.where(key: book_key_val.strip).empty?
  end

  def cat_exists?(category)
    q = @cats.where(category:).empty?
    !q
  end

  def cat_book_exists?(category, book_key)
    q = @cat_book.where(category:, book: book_key).empty?
    !q
  end

  def insert_cat_book(category, book_key)
    @cat_book.insert(category:, book: book_key) unless cat_book_exists?(category, book_key)
  end

  def books_with_desired_category
    # select CATS.category, BOOKS.* FROM CAT_BOOK LEFT JOIN CATS ON CAT_BOOK.CATEGORY = CATS.CATEGORY
    #   LEFT JOIN BOOKS ON CAT_BOOK.BOOK = BOOKS.KEY
    #   WHERE CATS.DESIRED AND LANGUAGE = 'English'
    books = @DB[:cat_book].left_join(:cats, category: :category).left_join(:books, key: Sequel[:cat_book][:book]).where(
      desired: true, language: 'English'
    ).distinct(:key)
  end

  def find_interesting_books(minimum_year: 0, minimum_stars: 3.8, minimum_ratings: 1000)
    books_with_desired_category.where do
      year >= minimum_year
    end.where { stars >= minimum_stars }.where { ratings >= minimum_ratings }.where(~has_read)
  end

  def is_interesting(key, minimum_year: 0, minimum_stars: 3.8, minimum_ratings: 1000)
    cats = @DB[:cats].right_join(:cat_book, category: :category).left_join(:books, key: Sequel[:cat_book][:book])
                     .where(key:)
                     .where(desired: true)
                     .where(language: 'English')
                     .where do
             year >= minimum_year
           end
                      .where { stars >= minimum_stars }
                     .where { ratings >= minimum_ratings }
                     .where(has_read: false)
    !cats.first.nil?
  end

  def insert_cat(newcat)
    @cats.insert(newcat) unless cat_exists?(newcat)
  end

  def get_book(key)
    @books.where(key:).first
  end

  def get_books_by_title(title)
    @books.filter(Sequel.ilike(:title, "%#{title}%"))
  end

  def get_books_by_author(author)
    @books.filter(Sequel.ilike(:author, "%#{author}%"))
  end

  def get_by_hash(filters) # This one uses case-insensitive filter and only certain fields
    @books.filter(Sequel.ilike(:title, "%#{filters[:title] || ''}%") &
                  Sequel.ilike(:author, "%#{filters[:author] || ''}%") &
          Sequel.ilike(:blurb, "%#{filters[:blurb] || ''}%"))
  end

  def get_by_hash_fuzzy(filters, threshold: 0.3)
    query = @books.dup

    # For titles, we use a standard ILIKE search. This is stable for phrases.
    if (title_filter = filters[:title] || '') > ''
      significant_words = title_filter.downcase.split.reject { |word| STOP_WORDS.include?(word) }
      significant_words.each { |word| query = query.where(Sequel.ilike(:title, "%#{word}%")) }
    end
    # For authors, we use Levenshtein distance, which is more intuitive for typos.
    if (author_filter = filters[:author] || '') > ''
      # Parse the user's input to get the last name.
      last_name_from_input = name_parse(author_filter)[:last]
      # Allow an edit distance of 1 for short names, 2 for longer ones.
      max_distance = last_name_from_input.length > 6 ? 2 : 2
      query = query.where(Sequel.lit('levenshtein(lower(get_last_name(author)), lower(?)) <= ?', last_name_from_input,
                                     max_distance))
    end

    # --- Ranking Phase ---
    order_expressions = []
    if (filters[:title] || '') > ''
      order_expressions << Sequel.function(:similarity, Sequel.function(:lower, :title),
                                           Sequel.function(:lower, filters[:title]))
    end
    if (filters[:author] || '') > ''
      last_name_from_input = name_parse(filters[:author])[:last]
      order_expressions << Sequel.function(:similarity, Sequel.function(:lower, Sequel.lit('get_last_name(author)')),
                                           Sequel.function(:lower, last_name_from_input))
    end

    return query.order(Sequel.desc(order_expressions.reduce(:+))) if order_expressions.any?

    query # Return the unordered query if no valid filters were provided.
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
    key = key[:key] if key.is_a? Book
    @books.filter(key:).update(year:)
  end

  def update_book_rating(book)
    @books.filter(key: book[:key]).update(stars: book[:stars], ratings: book[:ratings], stars_date: book[:stars_date],
                                          goodreads_title: book[:goodreads_title],
                                          goodreads_author: book[:goodreads_author])
  end

  def update_book_author_title(book)
    @books.filter(key: book[:key]).update(title: book[:title],
                                          author: book[:author], new_author: book[:new_author], new_title: book[:new_title])
  end

  def insert_wish(hash)
    author = (hash[:author] || '').strip
    title = (hash[:title] || '').strip
    if title.empty? || author.empty? # Both title and author are required
      puts 'Error - both title and author are required for wish list'
      return
    end
    b = get_by_hash({ title:, author: }).first # See if a matching book is already in the database
    if b # match
      read = if b[:has_read]
               'and has already been read'
             else
               'but had not yet been read'
             end
      puts "#{b[:title]} by #{b[:author]} is already an NLS BARD book (#{b[:key]})"
      puts "\t" + read

      return
    end
    if @wish.where(Sequel.ilike(:title, '%' + title + '%') & Sequel.ilike(:author, '%' + author + '%')).empty? # Make sure book not already in the list
      @wish.insert(title:, author:) # Insert it
    else
      puts "#{title} by #{author} is already in the wishlist"
    end
  end

  def list_wish # List the wishlist
    puts 'Wish list:'
    @wish.order(:author, :title).each { |w| puts "\t#{w[:title]} by #{w[:author]}" }
  end

  def wish_delete(hash)
    puts "Deleting from wish list, hash = #{hash}"
    return unless (hash[:id] || '') + (hash[:key] || '') + (hash[:title] || '') > ''

    @wish.filter(hash).delete
  end

  def wish_remove_by_title(partial_title)
    clean_title = partial_title.strip
    matches = @wish.filter(Sequel.ilike(:title, "%#{clean_title}%"))

    case matches.count
    when 0
      puts "No wishlist item found matching '#{clean_title}'."
    when 1
      item = matches.first
      puts "Found: '#{item[:title]}' by #{item[:author]}."
      print 'Are you sure you want to remove this item from the wishlist? (y/n) '
      confirmation = gets.chomp.downcase
      if confirmation == 'y'
        matches.delete
        puts 'Item removed from wishlist.'
      else
        puts 'Removal cancelled.'
      end
    else
      puts "Found multiple matches for '#{clean_title}'. Please be more specific."
      matches.each { |item| puts "  - '#{item[:title]}' by #{item[:author]}" }
    end
  end

  def check_for_wishlist_matches
    puts '(New) Checking for wishlist matches...'
    found_any = false

    # Iterate over each item in the wishlist and query for it individually.
    # This is more efficient than a single, complex JOIN on two ILIKE conditions.
    @wish.each do |wish_item|
      # Use the existing efficient search method.
      matching_books = get_by_hash({ title: wish_item[:title], author: wish_item[:author] })

      next if matching_books.empty?

      # Print the header only when the first match is found.
      unless found_any
        puts 'Found matches to wishlist:'
        found_any = true
      end

      matching_books.each do |book|
        puts "\t'#{wish_item[:title]}' matched: #{book[:title]} by #{book[:author]} (#{book[:key]})"
        # Update the wishlist item with the key of the found book.
        @wish.where(id: wish_item[:id]).update(key: book[:key])
      end
    end
    puts 'No new matches found for wishlist items.' unless found_any
  end

  def insert_book(newbook)
    # This method performs an "upsert" (update or insert) operation.
    # It uses PostgreSQL's `INSERT ... ON CONFLICT` feature to atomically
    # insert a new book or update an existing one if the key already exists.
    # This is more robust and efficient than checking for existence first.

    # Prepare the data hash, ensuring we only include valid columns from the 'books' table.
    book_data = {}
    newbook.keys.each do |k|
      book_data[k] = newbook[k] if @columns.include?(k)
    end
    return if book_data[:key].nil? || book_data[:key].empty? # Don't try to insert a book without a key

    # On conflict, we want to do nothing. This is a safety net in case
    # insert_book is called for a key that already exists. The main logic
    # in nls_bard.rb should prevent this, but this makes the operation safe.
    # The insert call returns nil if the row was ignored.
    result = @books.insert_conflict(
      target: :key,
      ignore: true
    ).insert(book_data)

    # If the insert was ignored (result is nil), do not process categories.
    return if result.nil?

    # The category association logic should only run for newly inserted books.
    return unless (newbook.category_array || []).count > 0

    newbook.category_array.each do |category|
      insert_cat(category)
      insert_cat_book(category, newbook[:key])
    end
  end

  def dump_database(output_file = nil)
    # Generate timestamped filename if none provided
    if output_file.nil?
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      output_file = "/app/db_dump/nls_bard_backup_#{timestamp}.sql"
    end

    db_name = @DB.opts[:database]
    host = @DB.opts[:host]
    user = @DB.opts[:user]
    password = @DB.opts[:password]

    # Ensure the output directory exists
    FileUtils.mkdir_p(File.dirname(output_file))

    # Use basic pg_dump that works reliably
    # The restore system will handle missing extensions/indexes
    cmd = [
      "PGPASSWORD='#{password}'",
      'pg_dump',
      "-h #{host}",
      "-U #{user}",
      "-d #{db_name}",
      "-f #{output_file}"
    ].join(' ')

    puts "Creating database backup..."
    puts "Output file: #{output_file}"
    
    # Execute the command
    system(cmd)

    if $?.success?
      # Keep only 2 generations of SQL files
      manage_backup_generations(output_file)

      puts "✓ Database backup completed successfully!"
      puts "✓ File: #{output_file}"
      puts ""
      puts "To restore this backup:"
      puts "  ./restore_database.sh #{output_file}"
    else
      puts "✗ Failed to dump database. Exit status: #{$?.exitstatus}"
    end
  rescue StandardError => e
    puts "Error during database dump or zip process: #{e.message}"
  end

  def manage_backup_generations(new_backup_file)
    backup_dir = File.dirname(new_backup_file)
    base_name = File.basename(new_backup_file, '.sql')
    
    # Look for existing backups with the same base pattern
    backup_pattern = File.join(backup_dir, "nls_bard_backup_*.sql")
    existing_backups = Dir.glob(backup_pattern).sort
    
    # If we have previous backups, rename the most recent one to .old
    if existing_backups.any?
      most_recent = existing_backups.last
      # Only rename if it's not the file we just created
      unless most_recent == new_backup_file
        old_backup = most_recent.gsub('.sql', '.old.sql')
        
        # Remove any existing .old file first
        File.delete(old_backup) if File.exist?(old_backup)
        
        # Rename current to .old
        File.rename(most_recent, old_backup)
        puts "Previous backup renamed to: #{File.basename(old_backup)}"
      end
    end
    
    # Clean up any backups older than 2 generations
    all_backups = Dir.glob(File.join(backup_dir, "nls_bard_backup_*.{sql,old.sql}"))
    if all_backups.length > 2
      # Sort by modification time and remove oldest
      old_files = all_backups.sort_by { |f| File.mtime(f) }[0...-2]
      old_files.each do |old_file|
        File.delete(old_file)
        puts "Removed old backup: #{File.basename(old_file)}"
      end
    end
  end

  private

  def setup_database_indexes
    # Check if we need to set up extensions and indexes
    # This handles both fresh databases and restored databases gracefully
    
    puts 'Ensuring required database extensions and indexes exist...'
    
    # Step 1: Ensure extensions exist (handle various scenarios)
    setup_extensions
    
    # Step 2: Ensure custom functions exist
    setup_custom_functions
    
    # Step 3: Ensure indexes exist (only after tables exist)
    setup_performance_indexes
    
    puts 'Database setup complete.'
  end

  def setup_extensions
    begin
      @DB.run('CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;')
      @DB.run('CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;')
    rescue Sequel::DatabaseError => e
      if e.message.include?('already exists with same argument types')
        puts 'Extensions already exist (from init scripts or restore), continuing...'
      elsif e.message.include?('duplicate key') && e.message.include?('pg_extension_name_index')
        puts 'Extensions already registered, continuing...'
      else
        puts "Extension setup warning: #{e.message}"
        # Continue anyway - the functions might exist from restore
      end
    end
  end

  def setup_custom_functions
    @DB.run("
      CREATE OR REPLACE FUNCTION get_last_name(full_name text) RETURNS text AS $$
      BEGIN
        IF position(',' in full_name) > 0 THEN
          RETURN trim(split_part(full_name, ',', 1));
        ELSE
          RETURN (string_to_array(trim(full_name), ' '))[array_upper(string_to_array(trim(full_name), ' '), 1)];
        END IF;
      END;
      $$ LANGUAGE plpgsql IMMUTABLE;
    ")
  end

  def setup_performance_indexes
    # Only create indexes if the books table actually exists
    return unless table_exists?(:books)
    
    indexes = [
      'CREATE INDEX IF NOT EXISTS books_title_lower_trgm_idx ON books USING gin (lower(title) gin_trgm_ops);',
      'CREATE INDEX IF NOT EXISTS books_author_lower_trgm_idx ON books USING gin (lower(author) gin_trgm_ops);',
      'CREATE INDEX IF NOT EXISTS books_read_by_lower_trgm_idx ON books USING gin (lower(read_by) gin_trgm_ops);',
      'CREATE INDEX IF NOT EXISTS books_last_name_trgm_idx ON books USING gin (lower(get_last_name(author)) gin_trgm_ops);'
    ]
    
    indexes.each do |index_sql|
      begin
        @DB.run(index_sql)
      rescue Sequel::DatabaseError => e
        puts "Index creation warning: #{e.message}"
        # Continue with other indexes
      end
    end
    
    puts 'Performance indexes configured.'
  end

  def table_exists?(table_name)
    @DB.table_exists?(table_name)
  end
end
