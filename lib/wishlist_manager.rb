#!/usr/bin/env ruby

require_relative 'google_sheets_integration'

module WishlistManager
  class SyncManager
    def initialize(database)
      @database = database
      @sheets_enabled = false
      @sheets_client = nil
    end
    
    def enable_sheets_sync
      return false unless GoogleSheetsIntegration.available?
      
      @sheets_client = GoogleSheetsIntegration.create_sync_client
      @sheets_enabled = !@sheets_client.nil?
      
      if @sheets_enabled
        puts "✓ Google Sheets integration enabled"
      else
        puts "⚠️  Google Sheets integration failed to initialize"
      end
      
      @sheets_enabled
    end
    
    def disable_sheets_sync
      @sheets_enabled = false
      @sheets_client = nil
      puts "Google Sheets sync disabled"
    end
    
    def sheets_enabled?
      @sheets_enabled && @sheets_client
    end
    
    # Sync operations
    def add_to_wishlist(title, author)
      # Add to database first
      @database.insert_wish(title: title, author: author)
      
      # Sync to sheets if enabled
      if sheets_enabled?
        sync_add_item(title, author)
      end
    end
    
    def mark_book_read(title, author)
      if sheets_enabled?
        sync_mark_read(title, author)
      end
    end
    
    def sync_full_wishlist
      return false unless sheets_enabled?
      
      puts "Performing full bidirectional sync with Google Sheets..."
      
      begin
        # Step 1: Import new items from Google Sheets
        puts "Step 1: Importing new items from Google Sheet..."
        imported_count = @sheets_client.import_new_items_to_local(@database)
        
        # Step 2: If we imported new items, run wishlist matching
        if imported_count > 0
          puts "Step 2: Running wishlist matching for newly imported items..."
          @database.check_for_wishlist_matches
        end
        
        # Step 3: Export complete wishlist back to Google Sheets
        puts "Step 3: Exporting complete wishlist to Google Sheet..."
        success = @sheets_client.sync_complete_wishlist_to_sheet(@database)
        
        if success
          puts "✓ Full bidirectional sync completed successfully"
        else
          puts "❌ Failed to complete bidirectional sync"
        end
        success
      rescue => e
        puts "❌ Error during bidirectional sync: #{e.message}"
        false
      end
    end
    
    def sync_after_book_session(newly_added_books = nil)
      return false unless sheets_enabled?
      
      puts "Performing post-session bidirectional sync..."
      
      begin
        # Step 1: Import new items from Google Sheets
        puts "Step 1: Importing new items from Google Sheet..."
        imported_count = @sheets_client.import_new_items_to_local(@database)
        
        # Step 2: Run wishlist matching (on new books if provided, otherwise all)
        puts "Step 2: Running wishlist matching..."
        if newly_added_books && newly_added_books.any?
          @database.check_for_wishlist_matches(newly_added_books)
        else
          @database.check_for_wishlist_matches
        end
        
        # Step 3: Export complete wishlist back to Google Sheets
        puts "Step 3: Exporting complete wishlist to Google Sheet..."
        success = @sheets_client.sync_complete_wishlist_to_sheet(@database)
        
        if success
          puts "✓ Post-session bidirectional sync completed successfully"
        else
          puts "❌ Failed to complete post-session sync"
        end
        success
      rescue => e
        puts "❌ Error during post-session sync: #{e.message}"
        false
      end
    end
    
    private
    
    def sync_add_item(title, author)
      return unless sheets_enabled?
      
      begin
        if @sheets_client.add_to_sheet(title, author)
          puts "✓ Added '#{title}' to Google Sheet"
        else
          puts "⚠️  Failed to add '#{title}' to Google Sheet"
        end
      rescue => e
        puts "⚠️  Google Sheets sync error: #{e.message}"
      end
    end
    
    def sync_mark_read(title, author)
      return unless sheets_enabled?
      
      begin
        if @sheets_client.mark_book_read_in_sheet(title, author)
          puts "✓ Marked '#{title}' as read in Google Sheet"
        else
          puts "⚠️  Could not find '#{title}' in Google Sheet to mark as read"
        end
      rescue => e
        puts "⚠️  Google Sheets sync error: #{e.message}"
      end
    end
  end
end