#!/bin/bash

# Comprehensive backup script
set -e

# Configuration
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$(pwd)/backups/full_backup_$TIMESTAMP"
MYSQL_USER=""
MYSQL_PASS=""
MYSQL_DATABASES=("database1" "database2")  # Add your database names here

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "=== Starting Full System Backup ==="
echo "Backup location: $BACKUP_DIR"

# Backup files
echo "Backing up application files..."
cp -r "$(pwd)/apps" "$BACKUP_DIR/"
cp -r "$(pwd)/config" "$BACKUP_DIR/"
cp "$(pwd)/.env" "$BACKUP_DIR/"

# Backup databases
if command -v mysql &> /dev/null && [ -n "$MYSQL_USER" ]; then
    echo "Backing up MySQL databases..."
    mkdir -p "$BACKUP_DIR/databases"
    
    for DB in "${MYSQL_DATABASES[@]}"; do
        echo "  - $DB"
        mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASS" "$DB" > "$BACKUP_DIR/databases/$DB.sql"
        gzip "$BACKUP_DIR/databases/$DB.sql"
    done
fi

# Backup SQLite databases
if [ -d "$(pwd)/data/db" ]; then
    echo "Backing up SQLite databases..."
    mkdir -p "$BACKUP_DIR/sqlite"
    cp "$(pwd)"/data/db/*.sqlite* "$BACKUP_DIR/sqlite/" 2>/dev/null || true
fi

# Create archive
echo "Creating backup archive..."
cd "$(pwd)/backups"
tar -czf "full_backup_$TIMESTAMP.tar.gz" "full_backup_$TIMESTAMP"
rm -rf "full_backup_$TIMESTAMP"

# Cleanup old backups (keep last 7 days)
find "$(pwd)" -name "full_backup_*.tar.gz" -type f -mtime +7 -delete

echo "=== Backup completed successfully! ==="
echo "Backup file: $(pwd)/full_backup_$TIMESTAMP.tar.gz"
exit 0
