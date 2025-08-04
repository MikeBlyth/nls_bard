# NLS_BARD APP

The purpose of this app is to make it more convenient to find and download audio books for the blind from the NLS Bard site (https://nlsbard.loc.gov/). The app

*   Downloads entries from the NLS database into a local Postgresql database
*   Gets Goodreads ratings for each book where they exist and adds that to the database
*   Keeps a wishlist and checks it against books that exist in the database
*   Provides tools for searching
*   Facilitates downloading titles

This project runs inside Docker to create a stable, consistent environment and avoid issues with local changes to Ruby, Chrome, or system dependencies.

## Installation and Setup

These instructions assume you are using WSL 2 on Windows, with Docker Desktop installed and integrated with your WSL distribution.

1.  **Clone the Repository:**
    ```bash
    git clone <your-repo-url>
    cd nls_bard
    ```

2.  **Configure Your Environment (One-Time Setup):**
    Create a `.env` file in the project root. This file stores your personal credentials and user configuration so Docker can run the application correctly without file permission errors.

    You can create this file automatically by running the command below. **You must edit the file afterwards** to add your NLS BARD username, password, and database password.

    ```bash
    cat <<EOF > .env
    # NLS Bard Credentials
    NLS_BARD_USERNAME=your_username_here
    NLS_BARD_PASSWORD=your_password_here
    
    # PostgreSQL Database Password
    POSTGRES_PASSWORD=a_strong_password_for_the_database
    
    # Path to your Windows Downloads folder (for WSL)
    # Example: /mnt/c/Users/YourUser/Downloads
    WIN_DOWNLOADS_PATH=/mnt/d/Users/mike/Downloads
    
    # Host User and Group ID for file permissions.
    # These are set automatically to match your current user.
    HOST_UID=$(id -u)
    HOST_GID=$(id -g)
    EOF
    ```

3.  **Build Docker Images:**
    With your `.env` file configured, build the images from the project root. You only need to do this once, or when you change the `Dockerfile` or `Gemfile`.
    ```bash
    docker-compose build
    ```

4.  **Database Setup (First Time Only):**
    - Start the database service: `docker-compose up -d db`
    - If you have a database dump (e.g., `nls_bard_db_dump.sql`) in the `db_dump` folder, restore it:
      ```bash
      docker-compose exec -T db psql -U mike -d nlsbard < db_dump/nls_bard_db_dump.sql
      ```

5.  **(Optional) Install Helper Scripts:** For convenience, you can copy the helper scripts to a location in your `PATH`.
    ```bash
    sudo cp nls nls-update /usr/local/bin/
    sudo chmod +x /usr/local/bin/nls /usr/local/bin/nls-update
    ```

## Usage

**Important:** The helper scripts (`nls`, `nls-update`) must be run from the project's root directory (the one containing `docker-compose.yml`).

The helper scripts start a temporary container, execute your command, and then prompt for the next command in an interactive session.


## Book Updates

I'm using Windows Task Scheduler to run `nls-update` daily in order to keep the catalog up to date, but this should be checked from time to time.

## Commands

Update the database of titles: `-g 30`

- This was intended to get the past <n> days, but it seems NLS just gives 30 days regardless of the number, so the update needs to run at least once a month or it will miss some titles.

Add a title to wish list: `-w -t "Tom Sawyer" -a Twain`

Check whether any wish list titles are found: `-w`

Remove an item from the wishlist: `--wish_remove "partial title"`

Find a title, can use title and/or author: `-f -t "Tom Sawyer" -a Twain [-v]`
- -v option gives long (verbose) output including whether and when the title was previously downloaded
- 
Download a title: `-d DB1234567`

The current configuration sends downloads into d:/users/mike/downloadsd. This is in the docker-compose.yaml file

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


## Shell files

These helper scripts are located in the project root and can be copied to a directory in your `PATH` (like `/usr/local/bin`) for convenience. They must be run from the project's root directory.

**`nls`:**
```
#!/bin/bash

# Default arguments if none are provided
DEFAULT_ARGS="-f -t 'x12xxx'"

# Check if arguments are provided
if [ $# -eq 0 ]; then
    ARGS="$DEFAULT_ARGS"
else
    ARGS="$@"
fi

# Run the docker-compose command with the appropriate arguments
docker-compose run --rm app ruby nls_bard.rb $ARGS
```
nls-update:
```
docker-compose run --rm app ruby nls_bard.rb -g 30
```

Updating the Docker Image

docker-compose build

Running a Shell Inside Container

docker-compose up -d
docker-compose exec app /bin/bash

# Revisions for new BARD (BARD2)

## URL for a specific item

The URL for a given item like DB128900 is https://nlsbard.loc.gov/bard2-web/search/DB128900/. 

## Downloading an item

Go the URL for that page and click on the link like

`<a href="/bard2-web/download/DB128900/?filename=DB-Baldacci_David%2520Strangers%2520in%2520time%253A%2520a%2520World%2520War%2520II%2520novel%2520DB128900&amp;prevPage=Strangers%20in%20time%3A%20a%20World%20War%20II%20novel%20DB128900&amp;from=%2Fsearch%2FDB128900%2F" role="link"><span>Download <span>Strangers in time: a World War II novel</span></span></a>`

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