#!/bin/bash
# Script to populate the development database from a known backup

set -e

# --- Configuration ---
# Path to the known good development database backup file
# IMPORTANT: This path is relative to your project root.
DEV_BACKUP_FILE="db_dump/dev/dev-nls_bard_dev_backup_20250806_141052.sql"

# --- Script Logic ---

echo "Checking if development database needs population..."

# Ensure the db service is running
echo "Ensuring development database service is running..."
docker-compose up -d db

# Wait a moment for the DB to be ready (optional, but good practice)
sleep 5

# Check if the 'books' table exists and has data
# If it doesn't exist or is empty, we assume the DB needs populating
if docker-compose exec -T db psql -U mike -d nlsbard -c "SELECT COUNT(*) FROM books LIMIT 1;" >/dev/null 2>&1; then
    BOOK_COUNT=$(docker-compose exec -T db psql -U mike -d nlsbard -t -c "SELECT COUNT(*) FROM books;" | xargs)
    if [[ "$BOOK_COUNT" -gt 0 ]]; then
        echo "Development database already contains data ($BOOK_COUNT books). Skipping population."
    else
        echo "Development database 'books' table is empty. Populating..."
        ./restore_database.sh --dev "$DEV_BACKUP_FILE"
        echo "✓ Development database populated successfully!"
    fi
else
    echo "Development database is empty or 'books' table does not exist. Populating..."
    ./restore_database.sh --dev "$DEV_BACKUP_FILE"
    echo "✓ Development database populated successfully!"
fi

echo "Development database population check complete."