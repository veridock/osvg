#!/bin/bash
# /osvg/monitor.sh

source /osvg/.env

# Sprawdź status aplikacji
check_apps() {
    sqlite3 "$DB_PATH" "SELECT name, domain FROM apps WHERE status='active';" | while IFS='|' read -r name domain; do
        if curl -f -s "https://$domain" > /dev/null; then
            echo "✓ $name ($domain) - OK"
        else
            echo "✗ $name ($domain) - FAILED"
            # Opcjonalnie: restart aplikacji
            systemctl restart caddy
        fi
    done
}

# Sprawdź wykorzystanie zasobów
check_resources() {
    echo "=== System Resources ==="
    echo "CPU Load: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"})')"
    
    # Alert jeśli dysk > 80%
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ $DISK_USAGE -gt 80 ]; then
        echo "⚠️ WARNING: Disk usage is above 80%!"
    fi
}

# Czyszczenie starych backupów (starsze niż 7 dni)
cleanup_old_backups() {
    find "$BACKUP_DIR" -type f -mtime +7 -delete
    echo "Old backups cleaned"
}

# Główna funkcja
main() {
    echo "=== PHP Platform Monitor ==="
    echo "Time: $(date)"
    echo ""
    
    check_apps
    echo ""
    check_resources
    echo ""
    cleanup_old_backups
    
    echo ""
    echo "=== Monitor Complete ==="
}

main >> "$PLATFORM_DIR/logs/monitor.log" 2>&1
