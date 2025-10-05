# Przykłady wywołań API

## 1. Dodanie nowej aplikacji

```bash
curl -X POST https://manager.local/api/apps \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-svg-app",
    "domain": "app.local",
    "git_uri": "git@github.com:user/svg-app.git",
    "public_key": "ssh-rsa AAAAB3..."
  }'
```

## 2. Pobranie listy aplikacji

```bash
curl -X GET https://manager.local/api/apps \
  -H "X-API-Key: YOUR_API_KEY"
```

## 3. Pobranie statusu systemu

```bash
curl -X GET https://manager.local/api/system/status \
  -H "X-API-Key: YOUR_API_KEY"
```

## 4. Pobranie logów systemowych

```bash
curl -X GET https://manager.local/api/system/logs \
  -H "X-API-Key: YOUR_API_KEY"
```

## 5. Aktualizacja statusu aplikacji

```bash
curl -X PUT https://manager.local/api/apps/1 \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"status": "maintenance"}'
```

## 6. Usunięcie aplikacji

```bash
curl -X DELETE https://manager.local/api/apps/1 \
  -H "X-API-Key: YOUR_API_KEY"
```

## 7. Ręczne wywołanie deployu

```bash
curl -X POST https://manager.local/api/deploy \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-svg-app",
    "domain": "app.local",
    "git_uri": "git@github.com:user/svg-app.git"
  }'
```
