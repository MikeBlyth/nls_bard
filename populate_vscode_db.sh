#!/bin/bash
# Script to populate the VS Code Dev Container database

set -e

echo "Populating VS Code Dev Container Database"
echo "=" * 50

# Check if VS Code dev container is running
if ! docker ps --format "table {{.Names}}" | grep -q "nls-bard-dev-container-db-1"; then
    echo "❌ VS Code Dev Container database is not running."
    echo "Please start VS Code with the dev container first."
    exit 1
fi

# Check if we have a dev backup to restore from
BACKUP_FILE=""
if [ -f "db_dump/dev/dev-nls_bard_dev_backup_20250806_141052.sql" ]; then
    BACKUP_FILE="db_dump/dev/dev-nls_bard_dev_backup_20250806_141052.sql"
    echo "Using existing dev backup: $BACKUP_FILE"
elif [ -n "$(ls db_dump/nls_bard_complete_backup_*.sql 2>/dev/null | head -1)" ]; then
    BACKUP_FILE="$(ls db_dump/nls_bard_complete_backup_*.sql | head -1)"
    echo "Using complete backup: $BACKUP_FILE"
else
    echo "❌ No backup file found."
    echo "Please create a backup first:"
    echo "  docker-compose up -d db"
    echo "  ./backup_database.sh --dev"
    exit 1
fi

# Restore the database
echo "Restoring database to VS Code Dev Container..."
if docker exec -i nls-bard-dev-container-db-1 psql -U mike -d nlsbard < "$BACKUP_FILE" > /dev/null 2>&1; then
    echo "✓ Database restored successfully!"
else
    echo "❌ Database restore failed. Check if the backup file is valid."
    exit 1
fi

# Set up test data (Mueller with has_read = 1)
echo "Setting up test data..."
docker exec -i nls-bard-dev-container-db-1 psql -U mike -d nlsbard -c \
    "UPDATE authors SET has_read = 1 WHERE last_name = 'Mueller' AND first_name = 'Robert' AND middle_name = 'S';" > /dev/null

echo "✓ Test data configured (Mueller has_read = 1)"

# Show statistics
BOOK_COUNT=$(docker exec -i nls-bard-dev-container-db-1 psql -U mike -d nlsbard -t -c "SELECT COUNT(*) FROM books;" | xargs)
AUTHOR_COUNT=$(docker exec -i nls-bard-dev-container-db-1 psql -U mike -d nlsbard -t -c "SELECT COUNT(*) FROM authors;" | xargs)

echo ""
echo "VS Code Dev Container Database Summary:"
echo "  Books: $BOOK_COUNT"
echo "  Authors: $AUTHOR_COUNT" 
echo "  Test case: Mueller, Robert S (has_read = 1)"
echo ""
echo "✓ VS Code Dev Container database is ready for debugging!"
echo ""
echo "You can now test from VS Code terminal:"
echo "  ruby nls_bard.rb -i    # Test interesting books with author indicators"
echo "  ruby nls_bard.rb -w    # Test wishlist with author indicators"