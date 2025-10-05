# Skrypty pomocnicze i konfiguracje

## 1. Docker Compose (opcjonalnie dla testów)

```yaml
# docker-compose.yml
version: '3.8'

services:
  php-platform:
    build: .
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - ./apps:/opt/php-platform/apps
      - ./data:/opt/php-platform/data
      - ./backups:/opt/php-platform/backups
      - caddy_data:/data
      - caddy_config:/config
    environment:
      - ADMIN_EMAIL=admin@example.com
    networks:
      - platform-network

volumes:
  caddy_data:
  caddy_config:

networks:
  platform-network:
```

## 2. Dockerfile

```dockerfile
# Dockerfile
FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    php8.2-fpm php8.2-cli php8.2-mbstring php8.2-xml \
    php8.2-zip php8.2-curl php8.2-gd php8.2-sqlite3 \
    caddy git curl wget sqlite3 supervisor

COPY install.sh /tmp/install.sh
RUN chmod +x /tmp/install.sh && /tmp/install.sh

EXPOSE 80 443 8080

CMD ["supervisord", "-n"]
```

## 3. Skrypt API (api.php)

```php
<?php
// /opt/php-platform/apps/manager/api.php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: X-API-Key, Content-Type');

// Sprawdzenie klucza API
$config = parse_ini_file('/opt/php-platform/.env');
$api_key = $_SERVER['HTTP_X_API_KEY'] ?? '';

if (empty($api_key)) {
    http_response_code(401);
    die(json_encode(['error' => 'API key required']));
}

// Weryfikacja klucza
$db = new SQLite3($config['DB_PATH']);
$stmt = $db->prepare("SELECT * FROM api_keys WHERE key_hash = :hash");
$stmt->bindValue(':hash', hash('sha256', $api_key), SQLITE3_TEXT);
$result = $stmt->execute();

if (!$result->fetchArray()) {
    http_response_code(401);
    die(json_encode(['error' => 'Invalid API key']));
}

// Router
$method = $_SERVER['REQUEST_METHOD'];
$path = $_SERVER['PATH_INFO'] ?? '/';
$segments = explode('/', trim($path, '/'));

// Główne endpointy
switch ($segments[0]) {
    case 'apps':
        handleApps($method, $segments, $db);
        break;
        
    case 'system':
        handleSystem($method, $segments);
        break;
        
    case 'deploy':
        handleDeploy($method);
        break;
        
    default:
        http_response_code(404);
        echo json_encode(['error' => 'Endpoint not found']);
}

function handleApps($method, $segments, $db) {
    switch ($method) {
        case 'GET':
            if (isset($segments[1])) {
                // Pobierz konkretną aplikację
                $stmt = $db->prepare("SELECT * FROM apps WHERE id = :id");
                $stmt->bindValue(':id', $segments[1], SQLITE3_INTEGER);
                $result = $stmt->execute();
                echo json_encode($result->fetchArray(SQLITE3_ASSOC));
            } else {
                // Lista wszystkich aplikacji
                $result = $db->query("SELECT * FROM apps ORDER BY created_at DESC");
                $apps = [];
                while ($row = $result->fetchArray(SQLITE3_ASSOC)) {
                    $apps[] = $row;
                }
                echo json_encode($apps);
            }
            break;
            
        case 'POST':
            $data = json_decode(file_get_contents('php://input'), true);
            $stmt = $db->prepare("INSERT INTO apps (name, domain, git_uri, public_key, path) 
                                   VALUES (:name, :domain, :git_uri, :public_key, :path)");
            $stmt->bindValue(':name', $data['name']);
            $stmt->bindValue(':domain', $data['domain']);
            $stmt->bindValue(':git_uri', $data['git_uri']);
            $stmt->bindValue(':public_key', $data['public_key'] ?? '');
            $stmt->bindValue(':path', "/opt/php-platform/apps/{$data['name']}");
            
            if ($stmt->execute()) {
                // Uruchom deployment
                $output = shell_exec("/opt/php-platform/deploy.sh '{$data['name']}' '{$data['git_uri']}' '{$data['domain']}' '{$data['public_key']}'");
                echo json_encode(['success' => true, 'output' => $output]);
            } else {
                http_response_code(500);
                echo json_encode(['error' => 'Failed to create app']);
            }
            break;
            
        case 'PUT':
            if (isset($segments[1])) {
                $data = json_decode(file_get_contents('php://input'), true);
                $stmt = $db->prepare("UPDATE apps SET status = :status WHERE id = :id");
                $stmt->bindValue(':status', $data['status']);
                $stmt->bindValue(':id', $segments[1]);
                
                if ($stmt->execute()) {
                    echo json_encode(['success' => true]);
                } else {
                    http_response_code(500);
                    echo json_encode(['error' => 'Failed to update app']);
                }
            }
            break;
            
        case 'DELETE':
            if (isset($segments[1])) {
                $stmt = $db->prepare("SELECT * FROM apps WHERE id = :id");
                $stmt->bindValue(':id', $segments[1]);
                $result = $stmt->execute();
                $app = $result->fetchArray(SQLITE3_ASSOC);
                
                if ($app) {
                    // Usuń pliki
                    shell_exec("rm -rf {$app['path']}");
                    shell_exec("rm -f /opt/php-platform/config/caddy/{$app['name']}.conf");
                    
                    // Usuń z bazy
                    $stmt = $db->prepare("DELETE FROM apps WHERE id = :id");
                    $stmt->bindValue(':id', $segments[1]);
                    $stmt->execute();
                    
                    // Przeładuj Caddy
                    shell_exec("systemctl reload caddy");
                    
                    echo json_encode(['success' => true]);
                } else {
                    http_response_code(404);
                    echo json_encode(['error' => 'App not found']);
                }
            }
            break;
    }
}

function handleSystem($method, $segments) {
    if ($method !== 'GET') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        return;
    }
    
    switch ($segments[1] ?? 'status') {
        case 'status':
            $status = [
                'cpu_load' => sys_getloadavg(),
                'memory' => [
                    'used' => memory_get_usage(true),
                    'peak' => memory_get_peak_usage(true)
                ],
                'disk' => [
                    'free' => disk_free_space('/'),
                    'total' => disk_total_space('/')
                ],
                'uptime' => shell_exec('uptime -p'),
                'php_version' => phpversion(),
                'hostname' => gethostname()
            ];
            echo json_encode($status);
            break;
            
        case 'logs':
            $logs = shell_exec('tail -n 100 /opt/php-platform/logs/platform.log');
            echo json_encode(['logs' => $logs]);
            break;
    }
}

function handleDeploy($method) {
    if ($method !== 'POST') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        return;
    }
    
    $data = json_decode(file_get_contents('php://input'), true);
    
    if (empty($data['name']) || empty($data['git_uri']) || empty($data['domain'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing required fields']);
        return;
    }
    
    $output = shell_exec("/opt/php-platform/deploy.sh '{$data['name']}' '{$data['git_uri']}' '{$data['domain']}' '{$data['public_key']}'");
    echo json_encode(['success' => true, 'output' => $output]);
}
```

## 4. Przykład wywołania API

```bash
# Dodanie nowej aplikacji przez API
curl -X POST https://manager.local/api/apps \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-svg-app",
    "domain": "app.local",
    "git_uri": "git@github.com:user/svg-app.git",
    "public_key": "ssh-rsa AAAAB3..."
  }'

# Pobranie listy aplikacji
curl -X GET https://manager.local/api/apps \
  -H "X-API-Key: YOUR_API_KEY"

# Status systemu
curl -X GET https://manager.local/api/system/status \
  -H "X-API-Key: YOUR_API_KEY"
```

## 5. Skrypt monitoringu (monitor.sh)

```bash
#!/bin/bash
# /opt/php-platform/monitor.sh

source /opt/php-platform/.env

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
    echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
    
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
```

## 6. Crontab dla automatyzacji

```bash
# Dodaj do /etc/crontab

# Monitoring co 5 minut
*/5 * * * * root /opt/php-platform/monitor.sh

# Aktualizacja aplikacji co godzinę
0 * * * * root /opt/php-platform/update-all.sh

# Backup co 6 godzin
0 */6 * * * root /opt/php-platform/backup-all.sh

# Czyszczenie logów raz dziennie
0 3 * * * root find /opt/php-platform/logs -type f -mtime +30 -delete

# Restart PHP-FPM raz w tygodniu (opcjonalnie)
0 4 * * 0 root systemctl restart php8.2-fpm
```

## 7. Konfiguracja zabezpieczeń (.htaccess)

```apache
# /opt/php-platform/apps/.htaccess

# Blokuj dostęp do wrażliwych plików
<FilesMatch "\.(env|db|sql|log)$">
    Order allow,deny
    Deny from all
</FilesMatch>

# Blokuj dostęp do katalogów git
RedirectMatch 404 /\.git

# Ustaw headers bezpieczeństwa
Header set X-Frame-Options "SAMEORIGIN"
Header set X-Content-Type-Options "nosniff"
Header set X-XSS-Protection "1; mode=block"
```

## 8. README.md dla repozytorium

```markdown
# RPi PHP Platform

System do zarządzania aplikacjami PHP na Raspberry Pi z automatycznym deploymentem.

## Instalacja

One-liner:
```bash
curl -sSL https://raw.githubusercontent.com/your-repo/rpi-php-platform/main/install.sh | sudo bash
```

## Funkcje

- ✅ Automatyczny deployment z Git
- ✅ Obsługa SVG z wbudowanym PHP
- ✅ Szyfrowanie Let's Encrypt przez Caddy
- ✅ Web IDE z edytorem i terminalem
- ✅ API do zarządzania aplikacjami
- ✅ Automatyczne backupy i rollback
- ✅ Monitoring systemu

## Użycie

### Dodanie aplikacji przez CLI:
```bash
/opt/php-platform/deploy.sh my-app git@github.com:user/repo.git app.local
```

### Przez API:
```bash
curl -X POST https://manager.local/api/apps \
  -H "X-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"my-app","domain":"app.local","git_uri":"git@github.com:user/repo.git"}'
```

### Przez Web UI:
Otwórz https://manager.local w przeglądarce.

## Struktura aplikacji

Aplikacje mogą być w dowolnym formacie obsługiwanym przez PHP:
- `.php` - standardowe pliki PHP
- `.svg` - SVG z wbudowanym PHP
- `.html` - HTML z PHP
- `.xml` - XML z PHP

## Licencja

MIT
```