#!/bin/bash
# Initialize the SQLite database

set -e

# Configuration
DB_DIR="/osvg/data/db"
DB_FILE="$DB_DIR/platform.db"
SCHEMA_FILE="/osvg/init-db.sql"

# Create database directory if it doesn't exist
mkdir -p "$DB_DIR"

# Check if database already exists
if [ -f "$DB_FILE" ]; then
    echo "Database already exists at $DB_FILE"
    echo "Remove it first if you want to reinitialize:"
    echo "  rm $DB_FILE"
    exit 1
fi

# Initialize database
echo "Initializing database at $DB_FILE..."
sqlite3 "$DB_FILE" < "$SCHEMA_FILE"

# Set permissions
chmod 664 "$DB_FILE"
chown www-data:www-data "$DB_FILE"
chown -R www-data:www-data "$DB_DIR"

echo "Database initialized successfully!"
echo "Location: $DB_FILE"

# Generate a random API key if not exists
if ! sqlite3 "$DB_FILE" "SELECT 1 FROM api_keys LIMIT 1;" 2>/dev/null; then
    API_KEY=$(openssl rand -hex 32)
    API_HASH=$(echo -n "$API_KEY" | sha256sum | awk '{print $1}')
    
    sqlite3 "$DB_FILE" "INSERT INTO api_keys (name, key_hash) VALUES ('Initial Admin Key', '$API_HASH');"
    
    echo ""
    echo "========================================"
    echo "IMPORTANT: Save this API key for authentication"
    echo "API Key: $API_KEY"
    echo "========================================"
    echo ""
    echo "You can use this key in your API requests with the header:"
    echo "X-API-Key: $API_KEY"
fi

exit 0
