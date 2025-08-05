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

if [ $# -eq 0 ]; then
  # If no arguments are provided, start an interactive bash session,
  # which is a useful default for development.
  docker-compose run --build --rm app /bin/bash
else
  # If arguments are provided, execute them as a command inside the container.
  docker-compose run --build --rm app "$@"
fi
