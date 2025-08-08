#!/usr/bin/env ruby

require 'sequel'
require 'dotenv/load'
require_relative 'name_parse'

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

def split_authors(author_field)
  return [] if author_field.nil? || author_field.strip.empty?
  author_field.split(';').map(&:strip).reject(&:empty?)
end

def main
  puts "Updating Author Download Counts"
  puts "=" * 40
  
  # Connect to database
  user = ENV.fetch('POSTGRES_USER', 'mike')
  password = ENV.fetch('POSTGRES_PASSWORD')
  host = ENV.fetch('POSTGRES_HOST', 'db')
  db_name = ENV.fetch('POSTGRES_DB', 'nlsbard')
  
  db = Sequel.connect("postgres://#{user}:#{password}@#{host}/#{db_name}")
  
  begin
    # First, check what field indicates downloaded books
    # Let's see what columns exist in books table
    books_columns = db[:books].columns
    puts "Available book fields: #{books_columns.join(', ')}"
    
    # Check for common fields that might indicate downloads
    downloaded_field = nil
    if books_columns.include?(:date_downloaded)
      downloaded_field = :date_downloaded
      condition_proc = proc { date_downloaded !~ nil }
      puts "Using 'date_downloaded' field (books with a download date)"
    elsif books_columns.include?(:has_read)  
      downloaded_field = :has_read
      condition_proc = proc { has_read =~ true }
      puts "Using 'has_read' field (books marked as read)"
    else
      puts "No clear download indicator found. Available fields:"
      puts books_columns.inspect
      puts "Please specify which field indicates downloaded books."
      exit 1
    end
    
    # Get count of books marked as downloaded
    downloaded_books = db[:books].where(&condition_proc)
    total_downloaded = downloaded_books.count
    puts "Found #{total_downloaded} downloaded books"
    
    if total_downloaded == 0
      puts "No downloaded books found. Nothing to update."
      exit 0
    end
    
    # Reset all author has_read counts to 0
    puts "Resetting all author download counts to 0..."
    db[:authors].update(has_read: 0)
    
    # Process each downloaded book
    puts "Processing downloaded books and updating author counts..."
    processed = 0
    authors_updated = 0
    
    downloaded_books.each do |book|
      processed += 1
      
      if processed % 100 == 0
        puts "  Processed #{processed}/#{total_downloaded} books, updated #{authors_updated} author records"
      end
      
      # Skip if no author field
      next if book[:author].nil? || book[:author].strip.empty?
      
      # Split multiple authors
      author_list = split_authors(book[:author])
      
      author_list.each do |author_name|
        # Parse the author name
        parsed = parse_author_name(author_name)
        next if parsed[:last].empty?
        
        # Find matching author in authors table and increment has_read
        begin
          updated_rows = db[:authors]
            .where(
              last_name: parsed[:last],
              first_name: parsed[:first], 
              middle_name: parsed[:middle]
            )
            .update(Sequel.expr(:has_read) + 1)
            
          if updated_rows > 0
            authors_updated += 1 if updated_rows > 0
          else
            puts "  Warning: Author not found in authors table: #{author_name}"
          end
        rescue => e
          puts "  Error updating author #{author_name}: #{e.message}"
        end
      end
    end
    
    puts "\n✓ Processing complete!"
    puts "  Processed #{processed} downloaded books"
    puts "  Updated #{authors_updated} author records"
    
    # Show statistics
    authors_with_downloads = db[:authors].where { has_read > 0 }.count
    total_download_count = db[:authors].sum(:has_read)
    max_downloads = db[:authors].max(:has_read)
    
    puts "\nDownload Count Statistics:"
    puts "  Authors with downloads: #{authors_with_downloads}"
    puts "  Total download count: #{total_download_count}"
    puts "  Maximum downloads by single author: #{max_downloads}"
    
    # Show top 10 most downloaded authors
    puts "\nTop 10 Most Downloaded Authors:"
    puts "%-20s | %-20s | %-20s | Downloads" % ["Last Name", "First Name", "Middle Name"]
    puts "-" * 80
    
    db[:authors]
      .where { has_read > 0 }
      .order(Sequel.desc(:has_read))
      .limit(10)
      .each do |author|
        puts "%-20s | %-20s | %-20s | %9d" % [
          author[:last_name], 
          author[:first_name], 
          author[:middle_name],
          author[:has_read]
        ]
      end
    
  rescue => e
    puts "\n✗ Error: #{e.message}"
    puts e.backtrace.first(5)
    exit 1
  ensure
    db.disconnect if db
  end
end

# Run the script
main if __FILE__ == $0