#!/bin/bash

# Update all components script
set -e

echo "=== Starting System Update ==="

# Update system packages
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Update Composer packages (if composer.json exists)
if [ -f "composer.json" ]; then
    echo "Updating PHP dependencies..."
    composer update --no-interaction --no-dev --optimize-autoloader
fi

# Update NPM packages (if package.json exists)
if [ -f "package.json" ]; then
    echo "Updating Node.js dependencies..."
    npm update
    
    # Build assets if needed
    if [ -f "webpack.mix.js" ] || [ -f "vite.config.js" ]; then
        echo "Building assets..."
        npm run prod
    fi
fi

# Run database migrations (if using Laravel)
if [ -f "artisan" ]; then
    echo "Running database migrations..."
    php artisan migrate --force
    
    # Clear caches
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache
fi

echo "=== Update completed successfully! ==="
exit 0
