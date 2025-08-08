#!/bin/bash
# Enhanced database backup script that includes all necessary components

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
    echo "Usage: $0 [--dev | --prod] [output_file.sql]"
    echo "Example (Dev): $0 --dev ./db_dump/dev-backup.sql"
    echo "Example (Prod): $0 --prod ./db_dump/prod-backup.sql"
    exit 1
fi

BACKUP_DIR="$(pwd)/db_dump"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ -z "$DUMP_FILE" ]; then
    if [ "$COMPOSE_FILE" == "docker-compose.prod.yml" ]; then
        BACKUP_FILE="$BACKUP_DIR/nls_bard_complete_backup_$TIMESTAMP.sql"
    else
        BACKUP_FILE="$BACKUP_DIR/dev/dev-nls_bard_complete_backup_$TIMESTAMP.sql"
    fi
else
    # Resolve provided DUMP_FILE to an absolute path
    BACKUP_FILE="$(realpath "$DUMP_FILE")"
fi

mkdir -p "$(dirname "$BACKUP_FILE")"

echo "Creating complete database backup..."

# Create a comprehensive backup that includes:
# - All data
# - Extensions (properly registered)
# - Custom functions
# - Indexes
docker-compose -f "$COMPOSE_FILE" exec -T db pg_dump -U mike -d nlsbard \
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
echo "  ./restore_database.sh --dev $BACKUP_FILE" # Suggest dev restore by default
