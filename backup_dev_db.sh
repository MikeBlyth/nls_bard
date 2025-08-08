#!/bin/bash
# Script to backup the development database from WSL command line

set -e

echo "Backing up Development Database"
echo "=" * 40

# Ensure the development database is running
echo "Starting development database if not running..."
docker-compose up -d db

# Wait a moment for DB to be ready
sleep 3

# Check if database is responding
if ! docker-compose exec -T db pg_isready -U mike -d nlsbard > /dev/null 2>&1; then
    echo "❌ Development database is not ready. Waiting longer..."
    sleep 5
    if ! docker-compose exec -T db pg_isready -U mike -d nlsbard > /dev/null 2>&1; then
        echo "❌ Development database failed to start properly."
        exit 1
    fi
fi

echo "✓ Development database is ready"

# Create backup filename with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="db_dump/dev"
BACKUP_FILE="$BACKUP_DIR/dev-nls_bard_dev_backup_$TIMESTAMP.sql"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Create the backup
echo "Creating backup: $BACKUP_FILE"
if docker-compose exec -T db pg_dump -U mike -d nlsbard --clean --if-exists > "$BACKUP_FILE"; then
    echo "✓ Backup created successfully!"
else
    echo "❌ Backup failed!"
    exit 1
fi

# Show backup info
BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
BOOK_COUNT=$(docker-compose exec -T db psql -U mike -d nlsbard -t -c "SELECT COUNT(*) FROM books;" | xargs)
AUTHOR_COUNT=$(docker-compose exec -T db psql -U mike -d nlsbard -t -c "SELECT COUNT(*) FROM authors;" | xargs)

echo ""
echo "Development Database Backup Summary:"
echo "  File: $BACKUP_FILE"
echo "  Size: $BACKUP_SIZE"
echo "  Books: $BOOK_COUNT"
echo "  Authors: $AUTHOR_COUNT"
echo ""
echo "✓ Development database backup complete!"
echo ""
echo "To restore this backup to VS Code container:"
echo "  ./populate_vscode_db.sh"
echo ""
echo "To restore this backup to production:"
echo "  ./restore_database.sh --prod $BACKUP_FILE"