#!/bin/bash
# Enhanced database backup script that includes all necessary components

set -e

BACKUP_DIR="./db_dump"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/nls_bard_complete_backup_$TIMESTAMP.sql"

mkdir -p "$BACKUP_DIR"

echo "Creating complete database backup..."

# Create a comprehensive backup that includes:
# - All data
# - Extensions (properly registered)
# - Custom functions
# - Indexes
docker-compose exec -T db pg_dump -U mike -d nlsbard \
    --verbose \
    --no-owner \
    --no-privileges \
    --create \
    --clean \
    --if-exists \
    > "$BACKUP_FILE"

echo "Backup created: $BACKUP_FILE"
echo ""
echo "This backup includes:"
echo "  - All table data"
echo "  - Extensions and functions"
echo "  - Indexes and constraints"
echo ""
echo "To restore on a new machine:"
echo "  ./restore_database.sh $BACKUP_FILE"