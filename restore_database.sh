#!/bin/bash
# Database restoration script that handles extensions and indexes properly

set -e

DUMP_FILE="$1"
if [ -z "$DUMP_FILE" ]; then
    echo "Usage: $0 <dump_file.sql>"
    echo "Example: $0 ./db_dump/nls_bard_backup_20250804_192120.sql"
    exit 1
fi

if [ ! -f "$DUMP_FILE" ]; then
    echo "Error: Dump file '$DUMP_FILE' not found"
    exit 1
fi

echo "Restoring database from: $DUMP_FILE"

# Stop the application container if running
echo "Stopping application container..."
docker-compose stop app 2>/dev/null || true

# Restore the database
echo "Restoring database..."
docker-compose exec -T db psql -U mike -d nlsbard < "$DUMP_FILE"

echo "Database restored successfully!"
echo "The application will automatically handle extensions and indexes on next startup."
echo ""
echo "To start the application:"
echo "  ./nls-dev.sh ruby nls_bard.rb -h"