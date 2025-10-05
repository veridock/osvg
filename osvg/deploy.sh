#!/bin/bash

# Deployment script for the application
set -e

# Variables
APP_DIR=$(pwd)
BACKUP_DIR="$APP_DIR/backups/$(date +%Y%m%d_%H%M%S)"

# Create backup before deployment
mkdir -p "$BACKUP_DIR"
echo "Creating backup in $BACKUP_DIR..."
cp -r "$APP_DIR/apps" "$BACKUP_DIR/"
cp -r "$APP_DIR/config" "$BACKUP_DIR/"
cp .env "$BACKUP_DIR/"

# Update application
echo "Updating application..."
# Add your deployment commands here
# Example: git pull

# Install dependencies
# composer install --no-dev --optimize-autoloader
# npm install --production
# npm run prod

# Run migrations
# php artisan migrate --force

# Clear caches
# php artisan config:cache
# php artisan route:cache
# php artisan view:cache

echo "Deployment completed successfully!"
exit 0
