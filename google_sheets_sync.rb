#!/usr/bin/env ruby

require 'google/apis/sheets_v4'
require 'googleauth'
require 'json'

class GoogleSheetsSync
  SHEET_ID = '1lzbFyKVTwjFfAAZLP5f-fyWmsCt38PdmejtfuZMo8aw'
  CREDENTIALS_FILE = 'nls-bard-5e76a5305047.json'
  
  def sheet_name
    # Use different sheet tabs based on environment
    environment = ENV['BARD_ENVIRONMENT'] || 'development'
    case environment.downcase
    when 'production'
      'Sheet1'
    when 'development', 'dev'
      'Test'
    else
      'Test'  # Default to test sheet for safety
    end
  end
  
  def initialize
    @service = Google::Apis::SheetsV4::SheetsService.new
    @service.authorization = authorize
  end
  
  def authorize
    unless File.exist?(CREDENTIALS_FILE)
      puts "❌ Google credentials file not found: #{CREDENTIALS_FILE}"
      puts "Please ensure the JSON file is in the project root directory."
      exit 1
    end
    
    Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: File.open(CREDENTIALS_FILE),
      scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS
    )
  end
  
  # Get all wishlist items from Google Sheet
  def get_sheet_wishlist
    range = "#{sheet_name}!A:F"
    
    begin
      response = @service.get_spreadsheet_values(SHEET_ID, range)
      rows = response.values || []
      
      # Skip header row if it exists
      if rows.first && rows.first[0]&.downcase.include?('title')
        rows = rows[1..-1]
      end
      
      wishlist_items = []
      rows.each_with_index do |row, index|
        next if row.empty? || row[0].nil? || row[0].strip.empty?
        
        title = row[0]&.strip || ''
        author = row[1]&.strip || ''
        read_cell = row[2]&.strip || ''
        
        # Debug read status detection (only show non-empty read cells)
        if !read_cell.empty?
          puts "📖 Read status found: '#{title}' = '#{read_cell}'"
        end
        
        # Check for read status - accept checkmark, "true", or any date-like string
        is_read = read_cell.downcase == 'true' || 
                  read_cell == '✓' || 
                  read_cell.match?(/\d+\/\d+\/\d+/) ||  # dates like 8/7/25
                  read_cell.match?(/\d+\-\d+\-\d+/)     # dates like 2025-08-07
        
        # Extract match details from columns D, E, F
        matched_title = row[3]&.strip || ''
        matched_author = row[4]&.strip || ''
        book_key = row[5]&.strip || ''
        
        wishlist_items << {
          title: title,
          author: author,
          read: is_read,
          matched_title: matched_title.empty? ? nil : matched_title,
          matched_author: matched_author.empty? ? nil : matched_author,
          book_key: book_key.empty? ? nil : book_key
        }
      end
      
      wishlist_items
    rescue Google::Apis::Error => e
      puts "❌ Error reading from Google Sheet: #{e.message}"
      []
    end
  end
  
  # Sync database wishlist to Google Sheet
  def sync_to_sheet(database_wishlist)
    # Prepare data for sheet (include header)
    sheet_data = [['Wishlist Title', 'Wishlist Author', 'Read', 'BARD Title', 'BARD Author', 'BARD Key']]
    
    database_wishlist.each do |item|
      sheet_data << [
        item[:title] || '',
        item[:author] || '', 
        item[:read] ? '✓' : '',
        item[:matched_title] || '',
        item[:matched_author] || '',
        item[:book_key] || ''
      ]
    end
    
    # Clear existing data and write new data
    range = "#{sheet_name}!A:F"
    
    begin
      # Clear the range first
      clear_request = Google::Apis::SheetsV4::ClearValuesRequest.new
      @service.clear_values(SHEET_ID, range, clear_request)
      
      # Write new data
      value_range = Google::Apis::SheetsV4::ValueRange.new(
        range: range,
        values: sheet_data
      )
      
      @service.update_spreadsheet_value(
        SHEET_ID,
        range,
        value_range,
        value_input_option: 'RAW'
      )
      
      puts "   ✅ Updated Google Sheet with #{database_wishlist.count} items (alphabetically sorted)"
      true
    rescue Google::Apis::Error => e
      puts "   ❌ Error writing to Google Sheet: #{e.message}"
      false
    rescue => e
      puts "   ❌ Unexpected error: #{e.message}"
      false
    end
  end
  
  # Update a specific book's read status in the sheet
  def mark_book_read_in_sheet(title, author)
    puts "Marking '#{title}' by #{author} as read in Google Sheet..."
    
    # Get current data to find the row
    range = "#{sheet_name}!A:F"
    
    begin
      response = @service.get_spreadsheet_values(SHEET_ID, range)
      rows = response.values || []
      
      # Find the matching row (skip header)
      row_index = nil
      rows.each_with_index do |row, index|
        next if index == 0 # Skip header
        if row[0]&.strip&.downcase == title.strip.downcase && 
           row[1]&.strip&.downcase == author.strip.downcase
          row_index = index + 1 # +1 because sheets are 1-indexed
          break
        end
      end
      
      if row_index
        # Update the Read column for this row
        update_range = "#{sheet_name}!C#{row_index}"
        value_range = Google::Apis::SheetsV4::ValueRange.new(
          range: update_range,
          values: [['✓']]
        )
        
        @service.update_spreadsheet_value(
          SHEET_ID,
          update_range,
          value_range,
          value_input_option: 'RAW'
        )
        
        puts "✓ Marked '#{title}' as read in Google Sheet"
        true
      else
        puts "⚠️  Book not found in Google Sheet: '#{title}' by #{author}"
        false
      end
    rescue Google::Apis::Error => e
      puts "❌ Error updating Google Sheet: #{e.message}"
      false
    end
  end
  
  # Add a new wishlist item to the sheet
  def add_to_sheet(title, author)
    puts "Adding '#{title}' by #{author} to Google Sheet..."
    
    # Find the next empty row
    range = "#{sheet_name}!A:F"
    
    begin
      response = @service.get_spreadsheet_values(SHEET_ID, range)
      rows = response.values || []
      next_row = rows.length + 1
      
      # Add the new item
      update_range = "#{sheet_name}!A#{next_row}:F#{next_row}"
      value_range = Google::Apis::SheetsV4::ValueRange.new(
        range: update_range,
        values: [[title, author, '', '', '', '']]
      )
      
      @service.update_spreadsheet_value(
        SHEET_ID,
        update_range,
        value_range,
        value_input_option: 'RAW'
      )
      
      puts "✓ Added '#{title}' to Google Sheet"
      true
    rescue Google::Apis::Error => e
      puts "❌ Error adding to Google Sheet: #{e.message}"
      false
    end
  end
  
  # Remove an item from the sheet
  def remove_from_sheet(title, author)
    puts "Removing '#{title}' by #{author} from Google Sheet..."
    
    # This is more complex - would need to delete a row
    # For now, just mark it for manual cleanup or implement full row deletion
    puts "⚠️  Manual removal from Google Sheet required for: '#{title}'"
  end

  # Sync interesting books to Google Sheet 'Interesting' page
  def sync_interesting_books_to_sheet(interesting_books)
    puts "📊 Writing #{interesting_books.count} interesting books to Google Sheet 'Interesting' page..."
    
    # Prepare data for sheet (include header)
    sheet_data = [['Category', 'Key', 'Title', 'Author', 'Rating', 'Ratings Count']]
    
    interesting_books.each do |book|
      # Extract first category from categories string
      categories = book[:categories] || ""
      first_category = categories.split(/[,;]/).first&.strip || "Uncategorized"
      
      sheet_data << [
        first_category,
        book[:key] || '',
        book[:title] || '',
        book[:author] || '',
        book[:stars] || '',
        book[:ratings] || ''
      ]
    end
    
    # Clear existing data and write new data to Interesting page
    range = "Interesting!A:F"
    
    begin
      # Clear the range first
      clear_request = Google::Apis::SheetsV4::ClearValuesRequest.new
      @service.clear_values(SHEET_ID, range, clear_request)
      
      # Write new data
      value_range = Google::Apis::SheetsV4::ValueRange.new(
        range: range,
        values: sheet_data
      )
      
      @service.update_spreadsheet_value(
        SHEET_ID,
        range,
        value_range,
        value_input_option: 'RAW'
      )
      
      puts "   ✅ Updated Google Sheet 'Interesting' page with #{interesting_books.count} books"
      true
    rescue Google::Apis::Error => e
      puts "   ❌ Error writing to Google Sheet 'Interesting' page: #{e.message}"
      false
    rescue => e
      puts "   ❌ Unexpected error writing interesting books: #{e.message}"
      false
    end
  end

  # Add a test method to manually set a read status for testing
  def set_read_status_for_testing(title_search, read_value = "8/7/25")
    range = "#{sheet_name}!A:F"
    
    begin
      response = @service.get_spreadsheet_values(SHEET_ID, range)
      rows = response.values || []
      
      # Find the matching row (skip header)
      rows.each_with_index do |row, index|
        next if index == 0 # Skip header
        if row[0]&.strip&.downcase&.include?(title_search.downcase)
          row_num = index + 1 # +1 because sheets are 1-indexed
          
          # Update the Read column for this row
          update_range = "#{sheet_name}!C#{row_num}"
          value_range = Google::Apis::SheetsV4::ValueRange.new(
            range: update_range,
            values: [[read_value]]
          )
          
          @service.update_spreadsheet_value(
            SHEET_ID,
            update_range,
            value_range,
            value_input_option: 'RAW'
          )
          
          puts "✓ Set read status '#{read_value}' for '#{row[0]}' in row #{row_num}"
          return true
        end
      end
      
      puts "⚠️  Book not found matching: '#{title_search}'"
      false
    rescue Google::Apis::Error => e
      puts "❌ Error updating Google Sheet: #{e.message}"
      false
    end
  end
end