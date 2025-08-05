# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby-based application that scrapes and manages audiobooks from the NLS BARD (National Library Service Braille and Audio Reading Download) website. The application runs in Docker containers to ensure consistent environments across different systems.

**Key Components:**
- **nls_bard.rb**: Main application entry point with command-line interface
- **nls_book_class.rb**: Book data model and display logic
- **nls_bard_sequel.rb**: Database interface using Sequel ORM
- **bard_session_manager.rb**: Selenium WebDriver session management
- **goodreads.rb**: Integration for fetching Goodreads ratings

## Development Commands

### Container Management
- **Development environment**: `./nls-dev.sh` or `./nls-dev.sh [command]`
- **Production environment**: `./nls-prod.sh [command]`
- **Build containers**: `docker-compose build`
- **Start database only**: `docker-compose up -d db`
- **Interactive shell**: `docker-compose run --rm app /bin/bash`

### Application Commands
Run these inside the container or via the shell scripts:

- **Update database**: `ruby nls_bard.rb -g 30` (gets last 30 days of books)
- **Search books**: `ruby nls_bard.rb -f -t "title" -a "author" [-v]`
- **Add to wishlist**: `ruby nls_bard.rb -w -t "title" -a "author"`
- **Check wishlist**: `ruby nls_bard.rb -w`
- **Download book**: `ruby nls_bard.rb -d DB123456`
- **Update ratings**: `ruby nls_bard.rb -u`
- **Backup database**: `ruby nls_bard.rb --backup`

### Testing and Quality
- **Run RSpec tests**: `bundle exec rspec`
- **Run RuboCop linter**: `bundle exec rubocop`
- **Debug mode**: Add `--debug` flag to any command

## Architecture

### Data Flow
1. **Web Scraping**: Selenium WebDriver navigates BARD2 website
2. **Data Processing**: Nokogiri parses HTML into Book objects
3. **Database Storage**: Sequel ORM manages PostgreSQL database
4. **Enhancement**: Goodreads API adds ratings data
5. **User Interface**: Command-line interface for search/download

### Database Schema
- **books**: Main book records (title, author, key, blurb, etc.)
- **cats**: Book categories/subjects
- **cat_book**: Many-to-many relationship between books and categories
- **wishlist**: User's desired books to track

### Key Classes
- **Book**: Hash-based data model with display methods
- **BookDatabase**: Database interface and query methods
- **BardSessionManager**: WebDriver session lifecycle management

## Environment Setup

The application requires a `.env` file in the project root with:
```
NLS_BARD_USERNAME=your_username
NLS_BARD_PASSWORD=your_password
POSTGRES_PASSWORD=database_password
WIN_DOWNLOADS_PATH=/path/to/downloads
HOST_UID=1000
HOST_GID=1001
```

## Important Notes

- **BARD2 Migration**: The application has been updated for the new BARD2 website structure
- **Docker Dependencies**: Chrome/Chromium and PostgreSQL run in containers
- **Download Handling**: Books download to the mapped Windows Downloads folder
- **Session Management**: WebDriver sessions are reused for efficiency
- **Fuzzy Search**: Database includes fuzzy matching for book searches
- **Case Insensitive**: Book IDs are handled case-insensitively but stored uppercase

## File Structure Patterns

- **Main scripts**: `nls_bard*.rb` files contain core functionality
- **Shell scripts**: `nls-*.sh` files are Docker wrapper scripts
- **Configuration**: `docker-compose*.yml` files for different environments
- **Data**: `db_dump/` contains database backups and restoration files