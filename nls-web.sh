#!/bin/bash
# Starts the BARD web interface on http://localhost:4567

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "$SCRIPT_DIR"

./populate_dev_db.sh

echo "Starting BARD web interface on http://localhost:4567"
docker-compose run --rm -p 4567:4567 app ruby web.rb
