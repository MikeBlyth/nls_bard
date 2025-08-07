# NLS BARD APP

The purpose of this app is to make it more convenient to find and download audio books for the blind from the NLS BARD site (https://nlsbard.loc.gov/). The app:

*   Downloads entries from the NLS database into a local PostgreSQL database
*   Gets Goodreads ratings for each book where they exist and adds that to the database
*   **Maintains a smart wishlist with bidirectional Google Sheets synchronization**
*   **Efficiently matches wishlist items against newly added books only**  
*   **Tracks downloaded books with date stamps instead of removing from wishlist**
*   Provides tools for searching with fuzzy matching support
*   Facilitates downloading titles
*   Tracks author reading statistics with automatic count updates
*   Includes robust network error handling with automatic retry mechanisms

This project runs inside Docker to create a stable, consistent environment and avoid issues with local changes to Ruby, Chrome, or system dependencies.

## Installation and Setup

Complete setup instructions for installing the NLS BARD app on a new system. These instructions assume you are using WSL 2 on Windows with Docker Desktop installed and integrated with your WSL distribution.

### Prerequisites

- **Docker Desktop**: Installed and running with WSL 2 integration enabled
- **WSL 2**: Ubuntu or similar Linux distribution
- **Git**: For cloning the repository
- **NLS BARD Account**: Valid username and password for https://nlsbard.loc.gov/

### Method 1: Quick Setup (Recommended for New Users)

This method downloads pre-built Docker images for faster setup:

1.  **Clone the Repository:**
    ```bash
    git clone <your-repo-url>
    cd nls_bard
    ```

2.  **Create Environment Configuration:**
    ```bash
    # Create .env file with your settings
    cat <<EOF > .env
    # NLS BARD Credentials (REQUIRED - Replace with your actual credentials)
    NLS_BARD_USERNAME=your_username_here
    NLS_BARD_PASSWORD=your_password_here
    
    # Database Password (REQUIRED - Choose a strong password)
    POSTGRES_PASSWORD=your_strong_database_password_here
    
    # Downloads Path (REQUIRED - Update with your actual path)
    # Example: /mnt/c/Users/YourName/Downloads
    WIN_DOWNLOADS_PATH=/mnt/d/Users/mike/Downloads
    
    # File Permissions (automatically set for current user)
    HOST_UID=$(id -u)
    HOST_GID=$(id -g)
    EOF
    ```

3.  **Edit the .env File:**
    ```bash
    nano .env  # or use your preferred editor
    ```
    **IMPORTANT**: Replace `your_username_here`, `your_password_here`, `your_strong_database_password_here`, and update the `WIN_DOWNLOADS_PATH` with your actual values.

4.  **Download Pre-built Images (if available):**
    ```bash
    # If Docker images are published to a registry:
    docker-compose pull
    
    # Or build locally (takes longer but always works):
    docker-compose build
    ```

5.  **Set Up Database:**
    ```bash
    # Start database service (if not already running)
    docker-compose up -d db
    
    # Ensure the development database is populated with initial data
    # This script will automatically restore from a known backup if the DB is empty.
    ./populate_dev_db.sh
    ```
    
6.  **Restore Database from Backup (Manual):**
    ```bash
    # If you need to manually restore a specific backup to the development database:
    ./restore_database.sh --dev db_dump/dev/dev-nls_bard_dev_backup_YYYYMMDD_HHMMSS.sql
    
    # To restore a production backup to the production database:
    ./restore_database.sh --prod db_dump/nls_bard_complete_backup_YYYYMMDD_HHMMSS.sql
    ```
    
7.  **Verify Installation:**
    ```bash
    # Test basic functionality
    ./nls-dev.sh -w                    # Should show empty wishlist or existing items
    ./nls-dev.sh -f -t "test"          # Should search database (now populated)
    ```

### Method 2: Build from Source (Advanced Users)

For development or if pre-built images aren't available:

1.  **Clone and Configure (same as Method 1, steps 1-3)**

2.  **Build Docker Images:**
    ```bash
    # Build development environment
    docker-compose build
    
    # Build production environment
    docker-compose -f docker-compose.prod.yml build
    ```

3.  **Database Setup (same as Method 1, steps 5-7)**

### Complete System Migration

If moving from an existing installation to a new system:

1.  **On Old System - Create Backup:**
    ```bash
    ./backup_database.sh --prod
    # This creates: db_dump/nls_bard_complete_backup_YYYYMMDD_HHMMSS.sql
    ```

2.  **Transfer Files:**
    - Copy the entire project directory to new system
    - Or: Clone fresh repository + copy `.env` file + copy database backup

3.  **On New System - Follow Method 1 above, then:**
    ```bash
    # Restore your data to the production environment
    ./restore_database.sh --prod db_dump/nls_bard_complete_backup_YYYYMMDD_HHMMSS.sql
    
    # Verify restoration
    ./nls-prod.sh -w                    # Check wishlist
    ./nls-prod.sh -f -t "some title"    # Search for known book
    ```

### Initial Database Population

If starting with an empty database:

```bash
# Get recent books (this may take 30+ minutes)
./nls-dev.sh -g 30

# Or for complete A-Z scrape (this may take several hours)
./nls-dev.sh --scrape_all_letters
```

## Usage

The project provides several convenience scripts for different environments:

- **`./nls-dev.sh [command]`** - Development environment (mounts current directory for live code editing)
- **`./nls-prod.sh [command]`** - Production environment (self-contained image)
- **`./rebuild-prod.sh`** - Rebuild production image after code changes

### Database Environments

The application uses three separate database environments to prevent corruption and enable safe development:

- **Production Environment** (`./nls-prod.sh`): Stable data for actual use. Database stored on host at `/home/mike/postgres-data-prod`
- **Development Environment** (`./nls-dev.sh`): Testing and development data. Uses Docker named volume `nls-bard_postgres_data_dev`
- **VS Code Dev Container**: Debugging and IDE integration. Uses Docker named volume `nls-bard-dev-container_postgres_data_dev`

**Key Benefits:**
- **No Corruption Risk**: Each environment has its own PostgreSQL instance and data storage
- **Safe Environment Switching**: Can run different environments simultaneously without conflicts
- **Debugging Support**: VS Code container database can be populated with subset of data for efficient debugging
- **Data Isolation**: Production data is completely protected from development activities

### Running Commands

```bash
# Development examples
./nls-dev.sh -f -t "Tom Sawyer"          # Search for books
./nls-dev.sh -w -t "Title" -a "Author"   # Add to wishlist  
./nls-dev.sh -g 30                       # Update database (30 days)

# Production examples (same commands, different script)
./nls-prod.sh -w                         # View wishlist
./nls-prod.sh -d DB123456                # Download book
./nls-prod.sh --backup                   # Create database backup

# Interactive shell for development
./nls-dev.sh                             # Opens bash shell in container

# Running a specific script in a container (e.g., for database population/updates)
# For development:
docker-compose run --rm --entrypoint="" app ruby populate_authors_table.rb
# For production:
docker-compose -f docker-compose.prod.yml run --rm --entrypoint="" app ruby populate_authors_table.rb
```

## Book Updates

Regular database updates should be run to keep the catalog current. The system will automatically handle network interruptions with retry mechanisms.

## Network Error Handling

The application includes robust error handling for network connectivity issues:

- **Automatic Retry**: Network operations retry up to 3 times with exponential backoff (2, 4, 6 seconds)
- **Fail-Safe Operation**: If retries fail, the application stops rather than continuing with incomplete data
- **Protected Operations**: 
  - Goodreads rating lookups (critical for book metadata)
  - NLS BARD website scraping (critical for book discovery)
  - Database operations (with duplicate prevention)
- **Clear Error Messages**: Detailed feedback when network issues occur

This ensures no books are processed without their complete metadata and prevents data corruption.

## Commands

### Core Database Operations

**Update the database of titles**: `-g 30`
- This was intended to get the past <n> days, but it seems NLS just gives 30 days regardless of the number, so the update needs to run at least once a month or it will miss some titles
- **NEW**: Automatically performs bidirectional Google Sheets sync after database updates
- **NEW**: Efficient wishlist matching only checks newly added books by default (use `--all` to check entire catalog)

**Find a title**: `-f -t "Tom Sawyer" -a Twain [-v]`
- Can use title and/or author for searching
- `-v` option gives long (verbose) output including download history
- Supports fuzzy matching for better search results

**Download a title**: `-d DB1234567`
- Downloads are saved to the directory specified in your `.env` file (`WIN_DOWNLOADS_PATH` variable)
- Automatically marks book as downloaded with date stamp
- Updates wishlist and Google Sheets if sync is enabled
- Increments author's read count in the authors table

**Mark a title as downloaded** (without actually downloading): `-X DB1234567` or `--mark-downloaded DB1234567`
- Use when you downloaded a book from another system but want to update your records
- Same effects as actual download: marks as read, updates wishlist, syncs to sheets

### Wishlist Management

**Add a title to wishlist**: `-w -t "Tom Sawyer" -a Twain`
- **NEW**: If book exists in database, immediately adds to wishlist with database key
- **NEW**: Automatically syncs to Google Sheets if enabled
- Shows whether book is already available or previously downloaded

**Check wishlist matches**: `-w`
- Lists current wishlist and shows any matches found in the database
- **NEW**: Displays color-coded indicators for authors you've read before
- **NEW**: Shows download dates for books you've already read

**Remove item from wishlist**: `--wish_remove "partial title"`
- Can search by partial title or database key (e.g., DB123456)
- Interactive confirmation before removal
- Only shows non-downloaded items for removal

### Google Sheets Integration

**Full bidirectional sync**: `--sync-sheets`
- Imports new items from Google Sheets to local wishlist
- Exports complete local wishlist to Google Sheets with match details
- Maintains 6-column format: Title, Author, Matched Title, Matched Author, Key, Read

**Efficient wishlist checking**: 
- Default behavior: Only check newly added books for wishlist matches (faster)
- Use `--all` flag with `-g` to check entire catalog (slower but comprehensive)

### Development and Testing

**Add test book**: `--test_add -t "Title" -a "Author" -k DB123456 [-d YYYY-MM-DD]`
- Adds a test book to database for development/testing
- Optional date parameter (defaults to today)
- Useful for testing wishlist matching and sync functionality

**Delete test book**: `--testdelete -k DB123456`
- Removes a test book from database
- Cleans up associated wishlist entries and category associations
- Use for cleaning up after testing

### Other Actions

Usage: nls_bard.rb [actions]

    -g, --getnew N			Update DB with books added in past N days

    -f, --find			Find in database (use title, author, and/or blurb)

    --mark x,y,z			Bookmark a set of books (DBxxxx)

    --unmark x,y,z			Remove bookmarks from a set of books (DBxxxx)

    --marked			Select marked books

    -w, --wish			Add to wishlist (use --author, --title), or print wishlist

    --wish_remove "partial title"	Remove item from wishlist by partial title match

    -d, --download x,y,z		Download books by key

    -X, --mark-downloaded x,y,z	Mark books as downloaded without actually downloading

    --[no-]debug			Debug (debug gem must be required in nls_bard.rb and 
    					debugger statement(s) included as breakpoings)

    -u, --update			Update ratings

    -m, --manual_update		Get user input for non-matches
   
    --backup			Backup database to zip file

	exit				Exits program after executing command on the command line
					(doesn't exit if a download was performed).
	
Filters:

    -t, --title TITLE                search database for title (use quotes)
    -a, --author AUTHOR              search database for author (use quotes)
    -b, --blurb CONTAINING           search database for blurb containing (use quotes)
    -k, --key KEY                    specify book key (e.g. DB60197)

Runtime options:

    -o, --output FILE                file for output
    -v, --[no-]verbose               Long descriptions; use with find
    -h, --help                       Show this message


## Shell Scripts

The project includes several shell scripts for different operations:

- **`./nls-dev.sh`** - Development environment wrapper
- **`./nls-prod.sh`** - Production environment wrapper  
- **`./rebuild-prod.sh`** - Rebuild production Docker image
- **`./backup_database.sh`** - Create comprehensive database backup
- **`./backup_dev_db.sh`** - Backup development database from WSL command line
- **`./restore_database.sh <file>`** - Restore database from backup
- **`./populate_vscode_db.sh`** - Populate VS Code Dev Container database

### Common Operations

**Updating Docker Images:**
```bash
# Development environment (automatically rebuilds when needed)
./nls-dev.sh 

# Production environment (requires manual rebuild after changes)
./rebuild-prod.sh
```

**Database Operations:**

The application maintains three separate database environments to prevent corruption and enable safe development:

1. **Production Database** - Stable data for actual use
2. **Development Database** - Testing and development data  
3. **VS Code Dev Container Database** - Debugging and IDE integration

```bash
# === BACKUP OPERATIONS ===

# Backup production database
./backup_database.sh --prod
# Creates: db_dump/nls_bard_complete_backup_YYYYMMDD_HHMMSS.sql

# Backup development database  
./backup_dev_db.sh
# Creates: db_dump/dev/dev-nls_bard_dev_backup_YYYYMMDD_HHMMSS.sql

# Legacy backup (detects environment automatically)
./backup_database.sh

# === RESTORE OPERATIONS ===

# Restore to production database
./restore_database.sh --prod db_dump/nls_bard_complete_backup_20250804_192120.sql

# Restore to development database
./restore_database.sh --dev db_dump/dev/dev-nls_bard_dev_backup_20250806_141052.sql

# Populate VS Code Dev Container database (run from WSL, not inside VS Code)
./populate_vscode_db.sh

# === INTERACTIVE ACCESS ===

# Production database
docker-compose -f docker-compose.prod.yml exec db psql -U mike -d nlsbard

# Development database  
docker-compose exec db psql -U mike -d nlsbard

# VS Code Dev Container database
docker exec -i nls-bard-dev-container-db-1 psql -U mike -d nlsbard
```

**Running Interactive Shell:**
```bash
./nls-dev.sh                    # Development shell
./nls-prod.sh /bin/bash         # Production shell (after build)
```

## Google Sheets Integration (Optional)

The application includes **bidirectional Google Sheets sync** for advanced wishlist management. This allows you to manage your wishlist through Google Sheets while maintaining automatic synchronization with the local database.

### Features

- **Import**: New items added to Google Sheets are automatically imported to local wishlist
- **Matching**: Local database is searched for matches to wishlist items  
- **Export**: Complete wishlist with match details is exported back to Google Sheets
- **Automatic Sync**: Runs during `-g` database updates for seamless operation
- **Master Interface**: Google Sheets becomes your primary wishlist management interface

### Setup

The project includes pre-configured Google Sheets integration:

- **Service Account**: `bookwishlist@nls-bard.iam.gserviceaccount.com`
- **Credentials**: Located in `google_credentials.json`
- **Sheet ID**: `1lzbFyKVTwjFfAAZLP5f-fyWmsCt38PdmejtfuZMo8aw`
- **Format**: 6-column layout (Title, Author, Matched Title, Matched Author, Key, Read)

### Workflow

1. **Add Books**: Add desired books to Google Sheets (Title and Author columns only)
2. **Daily Update**: Run `./nls-dev.sh -g 30` to update database and sync
3. **Automatic Processing**: 
   - App imports new items from sheet to local wishlist
   - Searches database for matches to wishlist items
   - Exports complete wishlist with match details back to sheet
4. **Results**: Matched books show database details; downloaded books marked with ✓

This creates a seamless workflow where Google Sheets serves as your wishlist interface while the app handles all the technical synchronization and matching.

# Revisions for new BARD (BARD2)

## URL for a specific item

The URL for a given item like DB128900 is https://nlsbard.loc.gov/bard2-web/search/DB128900/. 

## Downloading an item

Go the URL for that page and click on the link like

`<a href="/bard2-web/download/DB128900/?filename=DB-Baldacci_David%2520Strangers%2520in%2520time%253A%2520a%2520World%2520War%2520II%2520novel%2520DB128900&amp;prevPage=Strangers%2520in%2520time%253A%2520a%2520World%2520War%2520II%2520novel%2520DB128900&amp;from=%2Fsearch%2FDB128900%2F" role="link"><span>Download <span>Strangers in time: a World War II novel</span></span></a>`

## Get newly added books: iterate_update_pages
Entry URL = https://nlsbard.loc.gov/bard2-web/login/
From there, click on "Login with BARD" button to go to login page (https://nlsbard.loc.gov/bard2-web/login/)
Fill in credentials and click on "Login" button to go to home page (https://nlsbard.loc.gov/bard2-web/)

To get recently added items, the "base_url" for method iterate_update_pages is https://nlsbard.loc.gov/bard2-web/search/results/recently-added/?language=en&format=all&type=book
By default it includes 250 titles on a page. Iterate_update_pages gets a processed page using 

  ```
  page = get_page('', num, base_url) # i.e. puts HTML into page; get_page returns nil if finished
  entries = process_page(page)
  ```

then interates through entries using process_entry to parse the information for each book.

The link to the next page is like 

`<a href="/bard2-web/search/results/recently-added/?language=en&amp;format=all&amp;type=book&amp;offset=350" role="link"><span>Next page<!-- --> </span> ...`

Again, we can iterate by clicking on that link until it doesn't exist, which is probably the most robust solution.

## Format of Item on BARD2 (Search Results Page)

This is the format of a single book entry on the BARD2 pages.

```
    <div class="item-details" id="DB123456">
        <h4 class="item-link">
            <a href="/path/to/item">
                <span>Title of Item</span>
            </a>
        </h4>

        <div class="item-details-meta-container">
            <p data-testid="detail-value-p-author">
                <b data-testid="detail-value-b-author" class="author">Author: </b>Author Name
            </p>
            <p data-testid="detail-value-p-reading-time">
                <b data-testid="detail-value-b-reading-time" class="reading-time">Reading Time: </b>Duration
            </p>
            <p data-testid="detail-value-p-narrators-label">
                <b data-testid="detail-value-b-narrators-label" class="narrators-label">Read by: </b>Narrator Name
            </p>
            <p data-testid="detail-value-p-subjects">
                <b data-testid="detail-value-b-subjects" class="subjects">Subjects: </b>Subject Categories
            </p>
        </div>

        <p class="annotation">Description text content goes here.</p>

        <p class="publishers">Publisher Information</p>

        <div class="item-details-button-dropdown">
            <details id="button-dropdown-cta-buttons" class="button-dropdown">
                <summary role="button" aria-label="Take Action" class="button-dropdown-summary">
                    Take Action
                </summary>
                <div class="dropdown-submenu">
                    <ul>
                        <li>
                            <a class="download-link" href="/download/path" id="download-button">
                                <span>Download Item</span>
                            </a>
                        </li>
                        <li>
                            <a href="/wishlist/path" id="add-button">
                                <span>Add to Wish List</span>
                            </a>
                        </li>
                    </ul>
                </div>
            </details>
        </div>
    </div>
```

### Periodicals

We need to exclude periodicals, which have containers starting like this

`<div class="item-details ItemDetails_detailsContainer__W4rmf" id="DBpsychology-today_2025-07"><h4 class="item-link"><a href="/bard2-web/search/DBpsychology-today_2025-07/?prevPage=recentlyAdded&amp;from=%2Fsearch%2Fresults%2Frecently-added%2F%3FprevDays%3D%26type%3Dbook%26format%3Daudio%26language%3Den" `

The key differences are that the ID is not of the form /[A-Z]{1,3}[0-9]+/ and that the raw title does not have the ID appended. These entries should be ignored.