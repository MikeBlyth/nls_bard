#!/bin/bash
#
# nls-prod - Runs the NLS BARD application using the production Docker container.

# Exit immediately if a command exits with a non-zero status.
set -e

# Find the script's own directory to reliably locate the project root.
# This makes the script runnable from any location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Ensure we are in the project root so docker-compose can find its files.
cd "$SCRIPT_DIR"

# Check if development environment is running
if docker-compose ps --services --filter "status=running" | grep -q "db"; then
    echo "❌ Cannot start production environment: development environment is already running."
    echo ""
    echo "To switch to production:"
    echo "  docker-compose down"
    echo "  ./nls-prod.sh [command]"
    echo ""
    echo "To use development instead:"
    echo "  ./nls-dev.sh [command]"
    exit 1
fi

# Run the command in a new container.
# All script arguments ("$@") are passed to the container.
docker-compose -f docker-compose.prod.yml run --rm app "$@"