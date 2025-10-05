#!/bin/bash
# RPi PHP Platform Installer
# One-liner: curl -sSL https://example.com/install.sh | sudo bash

set -e

# Kolory dla outputu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== RPi PHP Platform Installer ===${NC}"

# Konfiguracja
PLATFORM_DIR="/opt/php-platform"
APPS_DIR="$PLATFORM_DIR/apps"
DATA_DIR="$PLATFORM_DIR/data"
BACKUP_DIR="$PLATFORM_DIR/backups"
CONFIG_DIR="$PLATFORM_DIR/config"
CADDY_CONFIG="/etc/caddy/Caddyfile"

# Aktualizacja systemu
echo -e "${YELLOW}Aktualizacja systemu...${NC}"
apt-get update && apt-get upgrade -y

# Instalacja zależności
echo -e "${YELLOW}Instalacja zależności...${NC}"
apt-get install -y \
    php8.2-fpm \
    php8.2-cli \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    php8.2-curl \
    php8.2-gd \
    php8.2-sqlite3 \
    php8.2-json \
    git \
    curl \
    wget \
    sqlite3 \
    supervisor \
    jq

# Instalacja Caddy
echo -e "${YELLOW}Instalacja Caddy...${NC}"
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install caddy -y

# Tworzenie struktury katalogów
echo -e "${YELLOW}Tworzenie struktury katalogów...${NC}"
mkdir -p $PLATFORM_DIR/{apps,data,backups,config,logs,temp}
mkdir -p $APPS_DIR/manager
mkdir -p $DATA_DIR/db

# Tworzenie bazy danych aplikacji
echo -e "${YELLOW}Inicjalizacja bazy danych...${NC}"
cat > $DATA_DIR/db/apps.sql << 'EOF'
CREATE TABLE IF NOT EXISTS apps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    domain TEXT NOT NULL,
    git_uri TEXT,
    public_key TEXT,
    path TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    version TEXT,
    last_update DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS deployments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_id INTEGER,
    commit_hash TEXT,
    deployed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    rollback_available BOOLEAN DEFAULT 1,
    FOREIGN KEY (app_id) REFERENCES apps (id)
);

CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key_hash TEXT NOT NULL UNIQUE,
    name TEXT,
    permissions TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_used DATETIME
);
EOF

sqlite3 $DATA_DIR/db/platform.db < $DATA_DIR/db/apps.sql

# Generowanie klucza API
API_KEY=$(openssl rand -hex 32)
API_KEY_HASH=$(echo -n "$API_KEY" | sha256sum | cut -d' ' -f1)
sqlite3 $DATA_DIR/db/platform.db "INSERT INTO api_keys (key_hash, name, permissions) VALUES ('$API_KEY_HASH', 'admin', 'all');"

# Tworzenie głównej konfiguracji Caddy
echo -e "${YELLOW}Konfiguracja Caddy...${NC}"
cat > $CADDY_CONFIG << 'EOF'
{
    auto_https on
    email admin@example.com
}

# Manager aplikacji
manager.local {
    root * /opt/php-platform/apps/manager
    php_fastcgi unix//run/php/php8.2-fpm.sock
    file_server
    encode gzip
    
    header {
        X-Frame-Options "SAMEORIGIN"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
    }
    
    @svg {
        path *.svg
    }
    handle @svg {
        php_fastcgi unix//run/php/php8.2-fpm.sock
    }
}

import /opt/php-platform/config/caddy/*.conf
EOF

mkdir -p $CONFIG_DIR/caddy

# Tworzenie pliku środowiskowego
echo -e "${YELLOW}Tworzenie konfiguracji środowiskowej...${NC}"
cat > $PLATFORM_DIR/.env << EOF
PLATFORM_DIR=$PLATFORM_DIR
APPS_DIR=$APPS_DIR
DATA_DIR=$DATA_DIR
BACKUP_DIR=$BACKUP_DIR
CONFIG_DIR=$CONFIG_DIR
DB_PATH=$DATA_DIR/db/platform.db
API_KEY=$API_KEY
ADMIN_EMAIL=admin@example.com
EOF

# Tworzenie skryptu deploymentu
echo -e "${YELLOW}Tworzenie skryptów systemowych...${NC}"
cat > $PLATFORM_DIR/deploy.sh << 'DEPLOY_SCRIPT'
#!/bin/bash
# Deploy script for apps

APP_NAME=$1
GIT_URI=$2
DOMAIN=$3
PUBLIC_KEY=$4

if [ -z "$APP_NAME" ] || [ -z "$GIT_URI" ] || [ -z "$DOMAIN" ]; then
    echo "Usage: deploy.sh <app_name> <git_uri> <domain> [public_key]"
    exit 1
fi

source /opt/php-platform/.env

APP_PATH="$APPS_DIR/$APP_NAME"

# Konfiguracja SSH dla Git
if [ ! -z "$PUBLIC_KEY" ]; then
    mkdir -p ~/.ssh
    echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
fi

# Klonowanie lub aktualizacja repozytorium
if [ -d "$APP_PATH" ]; then
    cd "$APP_PATH"
    git pull origin main
else
    git clone "$GIT_URI" "$APP_PATH"
fi

# Tworzenie konfiguracji Caddy dla aplikacji
cat > "$CONFIG_DIR/caddy/$APP_NAME.conf" << EOF
$DOMAIN {
    root * $APP_PATH
    php_fastcgi unix//run/php/php8.2-fpm.sock
    file_server
    encode gzip
    
    @svg {
        path *.svg
    }
    handle @svg {
        php_fastcgi unix//run/php/php8.2-fpm.sock
    }
    
    @xml {
        path *.xml
    }
    handle @xml {
        php_fastcgi unix//run/php/php8.2-fpm.sock
    }
}
EOF

# Aktualizacja bazy danych
sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO apps (name, domain, git_uri, public_key, path) VALUES ('$APP_NAME', '$DOMAIN', '$GIT_URI', '$PUBLIC_KEY', '$APP_PATH');"

# Przeładowanie Caddy
systemctl reload caddy

echo "Aplikacja $APP_NAME została wdrożona pod adresem: https://$DOMAIN"
DEPLOY_SCRIPT

chmod +x $PLATFORM_DIR/deploy.sh

# Tworzenie skryptu backup/rollback
cat > $PLATFORM_DIR/backup.sh << 'BACKUP_SCRIPT'
#!/bin/bash
# Backup and rollback script

ACTION=$1
APP_NAME=$2

source /opt/php-platform/.env

case $ACTION in
    backup)
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_PATH="$BACKUP_DIR/$APP_NAME_$TIMESTAMP"
        cp -r "$APPS_DIR/$APP_NAME" "$BACKUP_PATH"
        echo "Backup utworzony: $BACKUP_PATH"
        ;;
    rollback)
        if [ -z "$3" ]; then
            # Znajdź ostatni backup
            LATEST_BACKUP=$(ls -t $BACKUP_DIR/$APP_NAME_* | head -1)
        else
            LATEST_BACKUP="$BACKUP_DIR/$3"
        fi
        
        if [ -d "$LATEST_BACKUP" ]; then
            rm -rf "$APPS_DIR/$APP_NAME"
            cp -r "$LATEST_BACKUP" "$APPS_DIR/$APP_NAME"
            echo "Rollback wykonany z: $LATEST_BACKUP"
        else
            echo "Backup nie znaleziony"
            exit 1
        fi
        ;;
    *)
        echo "Usage: backup.sh [backup|rollback] <app_name> [backup_name]"
        exit 1
        ;;
esac
BACKUP_SCRIPT

chmod +x $PLATFORM_DIR/backup.sh

# Tworzenie automatycznej aktualizacji (cron)
cat > /etc/cron.d/php-platform << 'EOF'
# Automatyczna aktualizacja aplikacji co godzinę
0 * * * * root /opt/php-platform/update-all.sh >> /opt/php-platform/logs/update.log 2>&1

# Automatyczny backup co 6 godzin
0 */6 * * * root /opt/php-platform/backup-all.sh >> /opt/php-platform/logs/backup.log 2>&1
EOF

# Skrypt aktualizacji wszystkich aplikacji
cat > $PLATFORM_DIR/update-all.sh << 'UPDATE_SCRIPT'
#!/bin/bash
source /opt/php-platform/.env

sqlite3 "$DB_PATH" "SELECT name, path FROM apps WHERE status='active';" | while IFS='|' read -r name path; do
    echo "Aktualizacja: $name"
    cd "$path"
    git pull origin main
done
UPDATE_SCRIPT

chmod +x $PLATFORM_DIR/update-all.sh

# Skrypt backup wszystkich aplikacji  
cat > $PLATFORM_DIR/backup-all.sh << 'BACKUP_ALL'
#!/bin/bash
source /opt/php-platform/.env

sqlite3 "$DB_PATH" "SELECT name FROM apps WHERE status='active';" | while read -r name; do
    /opt/php-platform/backup.sh backup "$name"
done
BACKUP_ALL

chmod +x $PLATFORM_DIR/backup-all.sh

# Tworzenie usługi systemd dla platform managera
cat > /etc/systemd/system/php-platform.service << 'EOF'
[Unit]
Description=PHP Platform Manager
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/php-platform
ExecStart=/usr/bin/php -S 0.0.0.0:8080 -t /opt/php-platform/apps/manager
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Ustawienie uprawnień
chown -R www-data:www-data $PLATFORM_DIR
chmod -R 755 $PLATFORM_DIR

# Restart usług
echo -e "${YELLOW}Restart usług...${NC}"
systemctl daemon-reload
systemctl enable caddy
systemctl restart caddy
systemctl restart php8.2-fpm
systemctl enable php-platform
systemctl start php-platform

# Informacje końcowe
echo -e "${GREEN}=== Instalacja zakończona ===${NC}"
echo -e "${GREEN}Platform Manager dostępny pod: https://manager.local${NC}"
echo -e "${GREEN}API Key: $API_KEY${NC}"
echo -e "${YELLOW}Zapisz API Key w bezpiecznym miejscu!${NC}"
echo ""
echo -e "${GREEN}Aby dodać nową aplikację:${NC}"
echo "$PLATFORM_DIR/deploy.sh <app_name> <git_uri> <domain> [public_key]"
