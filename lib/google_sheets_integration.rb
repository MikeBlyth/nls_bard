#!/usr/bin/env ruby

require 'google/apis/sheets_v4'
require 'googleauth'
require 'json'

module GoogleSheetsIntegration
  class SheetsSync
    SHEET_ID = '1lzbFyKVTwjFfAAZLP5f-fyWmsCt38PdmejtfuZMo8aw'
    SHEET_NAME = 'Sheet1'
    CREDENTIALS_FILE = 'google_credentials.json'
    
    def initialize
      @service = Google::Apis::SheetsV4::SheetsService.new
      @service.authorization = authorize
    end
    
    private
    
    def authorize
      unless File.exist?(CREDENTIALS_FILE)
        raise "Google credentials file not found: #{CREDENTIALS_FILE}"
      end
      
      Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: File.open(CREDENTIALS_FILE),
        scope: Google::Apis::SheetsV4::AUTH_SPREADSHEETS
      )
    end
    
    public
    
    # Get all wishlist items from Google Sheet
    def get_sheet_wishlist
      range = "#{SHEET_NAME}!A:F"  # Extended to include new columns
      
      response = @service.get_spreadsheet_values(SHEET_ID, range)
      rows = response.values || []
      
      # Skip header row if it exists
      if rows.first && rows.first[0]&.downcase == 'title'
        rows = rows[1..-1]
      end
      
      wishlist_items = []
      rows.each do |row|
        next if row.empty? || row[0].nil? || row[0].strip.empty?
        
        wishlist_items << {
          title: row[0]&.strip || '',
          author: row[1]&.strip || '',
          matched_title: row[2]&.strip || '',
          matched_author: row[3]&.strip || '',
          key: row[4]&.strip || '',
          read: row[5]&.strip&.downcase == 'true' || row[5]&.strip == '✓'
        }
      end
      
      wishlist_items
    end
    
    # Import new items from sheet that don't exist in local wishlist
    def import_new_items_to_local(database)
      sheet_items = get_sheet_wishlist
      imported_count = 0
      
      sheet_items.each do |sheet_item|
        title = sheet_item[:title]
        author = sheet_item[:author]
        
        # Skip if either title or author is empty
        next if title.empty? || author.empty?
        
        # Check if this item already exists in local wishlist
        existing = database.wish.where(
          Sequel.ilike(:title, "%#{title}%") & 
          Sequel.ilike(:author, "%#{author}%")
        ).first
        
        # If not found locally, add it
        unless existing
          database.wish.insert(title: title, author: author)
          imported_count += 1
          puts "  Imported: '#{title}' by #{author}"
        end
      end
      
      if imported_count > 0
        puts "✓ Imported #{imported_count} new items from Google Sheet"
      else
        puts "✓ No new items to import from Google Sheet"
      end
      
      imported_count
    end
    
    # Sync database wishlist to Google Sheet with full bidirectional sync
    def sync_complete_wishlist_to_sheet(database)
      # Get all wishlist items from database, sorted alphabetically
      wishlist_items = database.wish.order(:title).all
      
      # Prepare data for sheet with new column structure
      sheet_data = [['Title', 'Author', 'Matched Title', 'Matched Author', 'Key', 'Read']]
      
      wishlist_items.each do |item|
        # Get matched book details if key exists
        matched_book = nil
        if item[:key] && !item[:key].empty?
          matched_book = database.get_book(item[:key])
        end
        
        sheet_data << [
          item[:title] || '',
          item[:author] || '',
          matched_book ? (matched_book[:title] || '') : '',
          matched_book ? (matched_book[:author] || '') : '',
          item[:key] || '',
          item[:date_downloaded] ? '✓' : ''
        ]
      end
      
      # Clear existing data and write new data (extended range for new columns)
      range = "#{SHEET_NAME}!A:F"
      
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
      
      puts "✓ Exported #{wishlist_items.count} items to Google Sheet (alphabetically sorted)"
      true
    end
    
    # Legacy method for backward compatibility  
    def sync_to_sheet(database_wishlist)
      # This method is kept for backward compatibility
      # For new workflow, use sync_complete_wishlist_to_sheet instead
      puts "⚠️  Using legacy sync method - consider upgrading to bidirectional sync"
      
      # Prepare data for sheet with old format
      sheet_data = [['Title', 'Author', 'Read']]
      
      database_wishlist.each do |item|
        sheet_data << [
          item[:title] || '',
          item[:author] || '', 
          item[:read] ? '✓' : ''
        ]
      end
      
      # Clear existing data and write new data
      range = "#{SHEET_NAME}!A:C"
      
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
      
      true
    end
    
    # Update a specific book's read status in the sheet
    def mark_book_read_in_sheet(title, author)
      # Get current data to find the row
      range = "#{SHEET_NAME}!A:C"
      
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
        update_range = "#{SHEET_NAME}!C#{row_index}"
        value_range = Google::Apis::SheetsV4::ValueRange.new(
          range: update_range,
          values: [['✓']]
        )
        
        @service.update_spreadsheet_values(
          SHEET_ID,
          update_range,
          value_range,
          value_input_option: 'RAW'
        )
        
        true
      else
        false
      end
    end
    
    # Add a new wishlist item to the sheet
    def add_to_sheet(title, author)
      # Find the next empty row
      range = "#{SHEET_NAME}!A:C"
      
      response = @service.get_spreadsheet_values(SHEET_ID, range)
      rows = response.values || []
      next_row = rows.length + 1
      
      # Add the new item
      update_range = "#{SHEET_NAME}!A#{next_row}:C#{next_row}"
      value_range = Google::Apis::SheetsV4::ValueRange.new(
        range: update_range,
        values: [[title, author, '']]
      )
      
      @service.update_spreadsheet_values(
        SHEET_ID,
        update_range,
        value_range,
        value_input_option: 'RAW'
      )
      
      true
    end
    
    # Remove an item from the sheet (placeholder for future implementation)
    def remove_from_sheet(title, author)
      # Row deletion is complex in Google Sheets API
      # For now, just return false to indicate manual cleanup needed
      false
    end
  end
  
  # Module-level convenience methods
  def self.create_sync_client
    SheetsSync.new
  rescue => e
    puts "⚠️  Failed to initialize Google Sheets sync: #{e.message}"
    nil
  end
  
  def self.available?
    File.exist?(SheetsSync::CREDENTIALS_FILE)
  end
end