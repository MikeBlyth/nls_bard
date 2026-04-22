# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby-based application that scrapes and manages audiobooks from the NLS BARD (National Library Service Braille and Audio Reading Download) website. The application runs in Docker containers to ensure consistent environments across different systems.

**Key Components:**
- **nls_bard.rb**: Main application entry point with command-line interface
- **nls_book_class.rb**: Book data model and display logic; extracts awards, year, target_age from blurb on import
- **nls_bard_sequel.rb**: Database interface using Sequel ORM
- **bard_session_manager.rb**: Selenium WebDriver session management
- **goodreads.rb**: Integration for fetching Goodreads ratings
- **web.rb**: Sinatra web application (search, wishlist, download UI)

## Development Commands

### Container Management
- **Development environment**: `./nls-dev.sh` or `./nls-dev.sh [command]`
- **Production environment**: `./nls-prod.sh [command]`
- **Rebuild production image**: `./rebuild-prod.sh` (rebuilds app+web services and restarts web)
- **Build containers**: `docker-compose build`
- **Start database only**: `docker-compose up -d db`
- **Interactive shell**: `docker-compose run --rm app /bin/bash`

### Web Server
- **Start (prod)**: `docker-compose -f docker-compose.prod.yml up -d web`
- **Logs**: `docker-compose -f docker-compose.prod.yml logs -f web`
- **Stop**: `docker-compose -f docker-compose.prod.yml stop web`
- Runs on port **4567**; dev container mounts `.:/app` so template changes are live without rebuild

### Application Commands
Run these inside the container or via the shell scripts:

- **Update database**: `ruby nls_bard.rb -g 30` (gets last 30 days of books)
- **Search books**: `ruby nls_bard.rb -f -t "title" -a "author" [-v]`
- **Add to wishlist**: `ruby nls_bard.rb -w -t "title" -a "author"`
- **Check wishlist**: `ruby nls_bard.rb -w`
- **Download book**: `ruby nls_bard.rb -d DB123456`
- **Update ratings**: `ruby nls_bard.rb -u`
- **Backup database**: `ruby nls_bard.rb --backup` or `./backup_database.sh`
- **Restore database**: `./restore_database.sh <backup_file.sql>`

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
5. **User Interface**: CLI and Sinatra web app (HTMX + Alpine.js + Tailwind)

### Database Schema
- **books**: Main book records (title, author, key, blurb, year, awards, reading_time, stars, ratings, language, etc.)
- **cats**: Normalized category strings (lowercase, deduplicated)
- **cat_book**: Many-to-many relationship between books and categories
- **wishlist**: User's desired books to track

#### Category notes
- `cats.category` and `cat_book.category` are stored **lowercase**; capitalize for display with `cat.split.map(&:capitalize).join(' ')`
- `books.categories` is a denormalized comma-separated string kept for the full-text search index (`document_v2`) — not used for display
- Display uses the `cat_book` relation exclusively

#### Awards
- `books.awards` is populated on import from the last 100 chars of the blurb via regex matching `Award|Prize`
- To backfill existing records: `UPDATE books SET awards = substring(RIGHT(blurb,100) FROM '[^.]*(Award|Prize)[^.]*') WHERE (awards IS NULL OR awards = '') AND RIGHT(blurb,100) ~ '(Award|Prize)'`

### Key Classes
- **Book**: Hash-based data model with display methods
- **BookDatabase**: Database interface and query methods
- **BardSessionManager**: WebDriver session lifecycle management

### Web UI (web.rb + views/)
- **Stack**: Sinatra, HTMX, Alpine.js, Tailwind CSS (CDN)
- **Search modes**: Find (ILIKE, OR across title+author when no author field), Fuzzy (Levenshtein), Full Text (tsvector/pgvector)
- **Filters**: media type (key prefix DB/BR), language, sort, limit, category
- **Category filter**: loads all cats on page load; after search, OOB-updates to show only cats from results
- **Downloads**: spawned via `spawn()` in a Thread; polls download dir for temp files to track completion; progress shown via HTMX polling of `/download/:key/status`
- **Award indicator**: red ★ prefix on titles where `books.awards` is non-empty

## Docker Setup

### Services
- **db**: pgvector/pgvector:pg13, port 5433 exposed (prod)
- **app**: CLI service, uses `nls-bard-prod:latest` image
- **web**: Web server service, same image as app, entrypoint `ruby web.rb`, port 4567

### Shared image
Both `app` and `web` use `image: nls-bard-prod:latest` in `docker-compose.prod.yml`. `./rebuild-prod.sh` builds this image once and restarts the web container.

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
- **Download Handling**: Books download to the mapped Windows Downloads folder (`CONTAINER_DOWNLOAD_PATH`)
- **Session Management**: WebDriver sessions are reused for efficiency
- **Fuzzy Search**: Database includes fuzzy matching for book searches
- **Case Insensitive**: Book IDs are handled case-insensitive but stored uppercase
- **Database Setup**: Automatic initialization handles extensions, functions, and indexes
- **Backup/Restore**: Use provided scripts for reliable database backup and restoration
- **Sinatra reloader**: Only reloads `web.rb` in development; changes to `nls_bard_sequel.rb` require restarting the web process

## File Structure Patterns

- **Main scripts**: `nls_bard*.rb` files contain core functionality
- **Shell scripts**: `nls-*.sh` files are Docker wrapper scripts
- **Configuration**: `docker-compose*.yml` files for different environments
- **Views**: `views/` contains ERB templates for the web UI
- **Data**: `db_dump/` contains database backups and restoration files
