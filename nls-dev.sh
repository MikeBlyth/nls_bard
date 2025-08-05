#!/bin/bash
#
# nls-dev - Runs commands in the NLS BARD development Docker container.

# Exit immediately if a command exits with a non-zero status.
set -e

# Find the script's own directory to reliably locate the project root.
# This makes the script runnable from any location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Ensure we are in the project root so docker-compose can find its files.
cd "$SCRIPT_DIR"

# Check if production environment is running
if docker-compose -f docker-compose.prod.yml ps --services --filter "status=running" | grep -q "db"; then
    echo "❌ Cannot start development environment: production environment is already running."
    echo ""
    echo "To switch to development:"
    echo "  docker-compose -f docker-compose.prod.yml down"
    echo "  ./nls-dev.sh [command]"
    echo ""
    echo "To use production instead:"
    echo "  ./nls-prod.sh [command]"
    exit 1
fi

COMMAND_TO_RUN=()
if [ $# -eq 0 ]; then
  # If no arguments are provided, start an interactive bash session,
  # which is a useful default for development.
  COMMAND_TO_RUN=("/bin/bash")
else
  # If arguments are provided, prepend "ruby nls_bard.rb" to them
  # to form a complete command to run inside the container.
  COMMAND_TO_RUN=("ruby" "nls_bard.rb" "$@")
fi

# Run the constructed command in the container.
docker-compose run --rm app "${COMMAND_TO_RUN[@]}"
