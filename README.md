# osvg

System jest gotowy do użycia i pozwala na łatwe zarządzanie wieloma aplikacjami PHP na Raspberry Pi Zero z pełną automatyzacją deploymentu i zarządzania.


### 🚀 Główne komponenty:

1. **Instalacja jednym poleceniem** - pełna konfiguracja systemu z Caddy, PHP-FPM, SQLite
2. **Manager aplikacji** - webowe IDE z:
    - Edytorem plików z kolorowaniem składni
    - Terminalem z dostępem do shell
    - Zarządzaniem aplikacjami (deploy, backup, rollback)
3. **Obsługa różnych formatów** - PHP, SVG, HTML, XML z wbudowanym PHP
4. **Automatyzacja** - Git sync, backupy, monitoring

### 📦 Instalacja:

```bash
# One-liner instalacyjny
curl -sSL https://your-domain.com/install.sh | sudo bash
```

### 🔧 Kluczowe funkcje:

- **Caddy z Let's Encrypt** - automatyczne certyfikaty SSL dla każdej aplikacji
- **Git deployment** - `deploy.sh app-name git-uri domain.com`
- **Web IDE** - edycja plików i terminal w przeglądarce
- **API REST** - pełne zarządzanie przez API
- **Auto-update** - cron aktualizuje aplikacje co godzinę
- **Backup/Rollback** - automatyczne kopie co 6 godzin

### 📱 Użycie:

1. **Manager dostępny pod**: `https://manager.local`
2. **Dodawanie aplikacji**:
    - Przez Web UI w zakładce "Aplikacje"
    - Przez API z kluczem autoryzacji
    - Przez CLI: `deploy.sh nazwa git-uri domena`

### 🎯 Przykład aplikacji SVG:

Dashboard systemowy w formacie SVG z PHP, który pokazuje:
- Metryki systemowe w czasie rzeczywistym
- Animowane wykresy
- Auto-odświeżanie co 5 sekund

```

## 2. One-liner instalacyjny

```bash
curl -sSL https://raw.githubusercontent.com/your-repo/rpi-php-platform/main/install.sh | sudo bash
```

## 3. Struktura katalogów

```
.
├── apps/               # Aplikacje
│   └── manager/        # Aplikacja zarządzająca
├── data/              # Dane
│   └── db/            # Bazy danych SQLite
├── backups/           # Kopie zapasowe
├── config/            # Konfiguracje
│   └── caddy/         # Konfiguracje domen Caddy
├── logs/              # Logi
├── temp/              # Pliki tymczasowe
├── .env               # Zmienne środowiskowe
├── deploy.sh          # Skrypt wdrażania
├── backup.sh          # Skrypt backup/rollback
├── update-all.sh      # Automatyczna aktualizacja
└── backup-all.sh      # Automatyczny backup
```

## 4. API Endpoints dla zarządzania

Manager aplikacji będzie udostępniał następujące endpointy:

- `POST /api/apps` - Dodawanie nowej aplikacji
- `GET /api/apps` - Lista aplikacji
- `PUT /api/apps/{id}` - Aktualizacja aplikacji
- `DELETE /api/apps/{id}` - Usunięcie aplikacji
- `POST /api/apps/{id}/deploy` - Wdrożenie aplikacji
- `POST /api/apps/{id}/rollback` - Rollback aplikacji
- `GET /api/system/status` - Status systemu