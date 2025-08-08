#!/bin/bash
#
# rebuild-prod.sh - Rebuilds the production Docker image with latest code changes
#
# This script rebuilds the production application image to pick up any code changes.
# Production uses a self-contained image (unlike dev which mounts the current directory),
# so this rebuild is necessary after making code changes.

# Exit immediately if a command exits with a non-zero status.
set -e

# Find the script's own directory to reliably locate the project root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Ensure we are in the project root so docker-compose can find its files.
cd "$SCRIPT_DIR"

echo "Rebuilding production application image with latest code changes..."
echo "This may take a few minutes..."

# Use this if getting missing-layer errors
# docker builder prune -f

# Rebuild the production app image
docker-compose -f docker-compose.prod.yml build app

echo "✓ Production image rebuilt successfully!"
echo ""
echo "The production environment now includes your latest code changes."
echo "You can now run production commands with the updated code:"
echo "  ./nls-prod.sh -w                    # View wishlist"
echo "  ./nls-prod.sh -f -t \"search term\"   # Search books"
echo "  ./nls-prod.sh --backup              # Create backup"
