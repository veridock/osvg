#!/bin/bash

# Backup and Rollback script
set -e

# Configuration
BACKUP_DIR="$(pwd)/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_$TIMESTAMP"

create_backup() {
    echo "Creating backup: $BACKUP_NAME"
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME"
    
    # Copy important directories
    cp -r "$(pwd)/apps" "$BACKUP_DIR/$BACKUP_NAME/"
    cp -r "$(pwd)/config" "$BACKUP_DIR/$BACKUP_NAME/"
    
    # Copy important files
    cp "$(pwd)/.env" "$BACKUP_DIR/$BACKUP_NAME/"
    
    echo "Backup created at: $BACKUP_DIR/$BACKUP_NAME"
}

list_backups() {
    echo "Available backups:"
    ls -l "$BACKUP_DIR" | grep '^d'
}

rollback() {
    local backup_name=$1
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [ ! -d "$backup_path" ]; then
        echo "Error: Backup $backup_name not found!"
        exit 1
    fi
    
    echo "Rolling back to: $backup_name"
    
    # Restore from backup
    cp -r "$backup_path/." "$(pwd)"
    
    echo "Rollback completed successfully!"
}

# Main script
case "$1" in
    create)
        create_backup
        ;;
    list)
        list_backups
        ;;
    rollback)
        if [ -z "$2" ]; then
            echo "Usage: $0 rollback <backup_name>"
            exit 1
        fi
        rollback "$2"
        ;;
    *)
        echo "Usage: $0 {create|list|rollback <backup_name>}"
        exit 1
        ;;
esac

exit 0
