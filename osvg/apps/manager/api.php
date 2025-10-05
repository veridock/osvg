<?php
// /osvg/apps/manager/api.php

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: X-API-Key, Content-Type');

// Sprawdzenie klucza API
$config = parse_ini_file('/osvg/.env');
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
            $stmt->bindValue(':path', "/osvg/apps/{$data['name']}");
            
            if ($stmt->execute()) {
                // Uruchom deployment
                $output = shell_exec("/osvg/deploy.sh '{$data['name']}' '{$data['git_uri']}' '{$data['domain']}' '{$data['public_key']}'");
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
                    shell_exec("rm -f /osvg/config/caddy/{$app['name']}.conf");
                    
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
            $logs = shell_exec('tail -n 100 /osvg/logs/platform.log');
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
    
    $output = shell_exec("/osvg/deploy.sh '{$data['name']}' '{$data['git_uri']}' '{$data['domain']}' '{$data['public_key']}'");
    echo json_encode(['success' => true, 'output' => $output]);
}
