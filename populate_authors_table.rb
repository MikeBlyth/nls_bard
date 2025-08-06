#!/usr/bin/env ruby

require 'sequel'
require 'dotenv/load'
require_relative 'name_parse'

# Enhanced name parsing for author table population
def parse_author_name(name)
  return {last: '', first: '', middle: ''} if name.nil? || name.strip.empty?
  
  name = name.strip
  
  # Handle corporate/organizational authors by putting them all in last_name
  if name.include?('(') || name.include?('Society') || name.include?('Association') || 
     name.include?('Institute') || name.include?('Organization') || name.include?('Inc.') ||
     name.include?('Corp.') || name.include?('Company') || name.include?('Press')
    return {last: name[0..19], first: '', middle: ''}
  end
  
  # Use existing name_parse function and truncate to fit varchar(20) fields
  parsed = name_parse(name)
  {
    last: (parsed[:last] || '')[0..19],
    first: (parsed[:first] || '')[0..19], 
    middle: (parsed[:middle] || '')[0..19]
  }
end

# Split multiple authors separated by semicolons
def split_authors(author_field)
  return [] if author_field.nil? || author_field.strip.empty?
  
  # Split on semicolon and clean up each author
  authors = author_field.split(';').map(&:strip).reject(&:empty?)
  authors
end

def create_authors_table(db)
  puts "Creating authors table..."
  
  # Drop table if exists and create new one
  db.drop_table?(:authors)
  
  db.create_table :authors do
    varchar :last_name, size: 20, null: false
    varchar :first_name, size: 20, null: false  
    varchar :middle_name, size: 20, null: false
    
    # Unique constraint on all three fields
    unique [:last_name, :first_name, :middle_name]
    
    index [:last_name]
    index [:first_name] 
  end
  
  puts "✓ Authors table created with unique constraint on (last_name, first_name, middle_name)"
end

def populate_authors_table(db)
  puts "Populating authors table from books data..."
  
  books = db[:books]
  authors_table = db[:authors]
  
  total_books = books.count
  processed = 0
  authors_added = 0
  
  puts "Processing #{total_books} books..."
  
  books.each do |book|
    processed += 1
    
    if processed % 1000 == 0
      puts "  Processed #{processed}/#{total_books} books, added #{authors_added} unique authors"
    end
    
    # Skip if no author field
    next if book[:author].nil? || book[:author].strip.empty?
    
    # Split multiple authors
    author_list = split_authors(book[:author])
    
    author_list.each do |author_name|
      # Parse the author name
      parsed = parse_author_name(author_name)
      
      # Skip if parsing resulted in empty names
      next if parsed[:last].empty?
      
      # Insert author (ignore duplicates due to unique constraint)
      begin
        authors_table.insert(
          last_name: parsed[:last],
          first_name: parsed[:first],
          middle_name: parsed[:middle]
        )
        authors_added += 1
      rescue Sequel::UniqueConstraintViolation
        # Author already exists, skip silently
      end
    end
  end
  
  puts "✓ Finished processing #{processed} books"
  puts "✓ Added #{authors_added} unique authors to the database"
  
  # Show some statistics
  total_authors = authors_table.count
  corporate_authors = authors_table.where(first_name: '', middle_name: '').count
  individual_authors = total_authors - corporate_authors
  
  puts "\nAuthor Statistics:"
  puts "  Total unique authors: #{total_authors}"
  puts "  Individual authors: #{individual_authors}"
  puts "  Corporate/organizational authors: #{corporate_authors}"
end

def show_sample_authors(db)
  puts "\nSample authors (first 20):"
  puts "%-20s | %-20s | %-20s" % ["Last Name", "First Name", "Middle Name"]
  puts "-" * 68
  
  db[:authors].limit(20).each do |author|
    puts "%-20s | %-20s | %-20s" % [
      author[:last_name], 
      author[:first_name], 
      author[:middle_name]
    ]
  end
end

# Main execution
def main
  puts "NLS BARD Authors Table Population Script"
  puts "=" * 50
  
  # Connect to database
  user = ENV.fetch('POSTGRES_USER', 'mike')
  password = ENV.fetch('POSTGRES_PASSWORD')
  host = ENV.fetch('POSTGRES_HOST', 'db')
  db_name = ENV.fetch('POSTGRES_DB', 'nlsbard')
  
  db = Sequel.connect("postgres://#{user}:#{password}@#{host}/#{db_name}")
  
  begin
    # Create the authors table
    create_authors_table(db)
    
    # Populate from books data
    populate_authors_table(db)
    
    # Show sample results
    show_sample_authors(db)
    
    puts "\n✓ Authors table population completed successfully!"
    
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