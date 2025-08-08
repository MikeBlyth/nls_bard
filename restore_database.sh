#!/bin/bash
# Database restoration script that handles extensions and indexes properly

set -e

COMPOSE_FILE=""

# Parse arguments for --prod or --dev
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --prod)
      COMPOSE_FILE="docker-compose.prod.yml"
      echo "Running in production mode..."
      shift # past argument
      ;;
    --dev)
      COMPOSE_FILE="docker-compose.yml"
      echo "Running in development mode..."
      shift # past argument
      ;;
    *)
      # First non-flag argument is the dump file
      if [ -z "$DUMP_FILE" ]; then
        DUMP_FILE="$1"
      fi
      shift # past argument or value
      ;;
  esac
done

# Check if a compose file was selected
if [ -z "$COMPOSE_FILE" ]; then
    echo "Error: Please specify either --dev or --prod."
    echo "Usage: $0 [--dev | --prod] <dump_file.sql>"
    echo "Example (Dev): $0 --dev ./db_dump/nls_bard_backup_20250804_192120.sql"
    echo "Example (Prod): $0 --prod ./db_dump/nls_bard_backup_20250804_192120.sql"
    exit 1
fi

if [ -z "$DUMP_FILE" ]; then
    echo "Error: No dump file specified."
    echo "Usage: $0 [--dev | --prod] <dump_file.sql>"
    echo "Example (Dev): $0 --dev ./db_dump/nls_bard_backup_20250804_192120.sql"
    echo "Example (Prod): $0 --prod ./db_dump/nls_bard_backup_20250804_192120.sql"
    exit 1
fi

if [ ! -f "$DUMP_FILE" ]; then
    echo "Error: Dump file '$DUMP_FILE' not found"
    exit 1
fi

echo "Restoring database from: $DUMP_FILE"

# Stop the application container if running
echo "Stopping application container..."
docker-compose -f "$COMPOSE_FILE" stop app 2>/dev/null || true

# Restore the database
echo "Restoring database..."
docker-compose -f "$COMPOSE_FILE" cp "$DUMP_FILE" db:/tmp/dump.sql
docker-compose -f "$COMPOSE_FILE" exec -T db psql -U mike -d nlsbard -f /tmp/dump.sql

echo "Database restored successfully!"
echo "The application will automatically handle extensions and indexes on next startup."
echo ""
echo "To start the application:"
echo "  ./nls-dev.sh ruby nls_bard.rb -h"