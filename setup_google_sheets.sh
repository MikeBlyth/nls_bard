#!/bin/bash
# Setup script for Google Sheets integration

set -e

echo "Google Sheets Integration Setup"
echo "=" * 40

# Check if credentials file exists
if [ ! -f "google_credentials.json" ]; then
    echo "❌ Google credentials file not found!"
    echo ""
    echo "Please follow these steps:"
    echo "1. Go to https://console.cloud.google.com/"
    echo "2. Select your project: nls-bard-app (or whatever you named it)"
    echo "3. Enable Google Sheets API"
    echo "4. Create Service Account credentials"
    echo "5. Download the JSON file"
    echo "6. Save it as 'google_credentials.json' in this directory"
    echo ""
    echo "Then share your Google Sheet with the service account email"
    echo "Sheet URL: https://docs.google.com/spreadsheets/d/1lzbFyKVTwjFfAAZLP5f-fyWmsCt38PdmejtfuZMo8aw/edit"
    exit 1
fi

echo "✓ Found google_credentials.json"

# Extract service account email from credentials
SERVICE_ACCOUNT_EMAIL=$(grep -o '"client_email"[^,]*' google_credentials.json | cut -d'"' -f4)
echo "Service account email: $SERVICE_ACCOUNT_EMAIL"

# Install the Google API gem (rebuild Docker images)
echo "Installing Google Sheets API gem..."
echo "This will rebuild your Docker images to include the new gem."
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Rebuild development image
echo "Rebuilding development Docker image..."
docker-compose build

# Rebuild production image
echo "Rebuilding production Docker image..."
docker-compose -f docker-compose.prod.yml build

echo ""
echo "✓ Google Sheets integration setup complete!"
echo ""
echo "Usage:"
echo "  # Sync entire wishlist to Google Sheet"
echo "  ./nls-dev.sh --sync-sheets"
echo ""  
echo "  # Add item to wishlist (will auto-sync if enabled)"
echo "  ./nls-dev.sh -w -t \"Book Title\" -a \"Author Name\""
echo ""
echo "  # Download book (will mark as read in sheet)"
echo "  ./nls-dev.sh -d DB123456"
echo ""
echo "Make sure you've shared your Google Sheet with:"
echo "$SERVICE_ACCOUNT_EMAIL"