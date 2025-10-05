# PHP Platform Documentation

## Overview

This is a PHP application platform with Docker support, designed for managing multiple PHP applications with ease. It includes features like automated deployment, backup, and monitoring.

## Project Structure

```
.
├── apps/                 # Application directories
│   └── manager/          # Management interface
├── config/               # Configuration files
│   └── caddy/            # Caddy server configurations
├── data/                 # Application data
│   └── db/               # Database files
├── scripts/              # Utility scripts
├── .env                  # Environment variables
├── docker-compose.yml    # Docker Compose configuration
└── Dockerfile            # Docker configuration
```

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Git
- Make (optional, but recommended)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/php-platform.git
   cd php-platform
   ```

2. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

3. Update the `.env` file with your configuration.

4. Build and start the containers:
   ```bash
   docker-compose up -d --build
   ```

5. Initialize the database:
   ```bash
   docker-compose exec app ./scripts/init-database.sh
   ```

6. Access the management interface at `http://localhost:8080`

## Usage

### Managing Applications

#### Add a new application

```bash
curl -X POST http://localhost:8080/api/apps \
  -H "X-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "domain": "app.local",
    "git_uri": "git@github.com:user/repo.git"
  }'
```

#### List all applications

```bash
curl -X GET http://localhost:8080/api/apps \
  -H "X-API-Key: YOUR_API_KEY"
```

### Backup and Restore

#### Create a backup

```bash
./scripts/backup.sh create
```

#### List available backups

```bash
./scripts/backup.sh list
```

#### Restore from backup

```bash
./scripts/backup.sh restore backup_20231005_120000
```

## Development

### Running Tests

```bash
docker-compose exec app composer test
```

### Building for Production

```bash
docker-compose -f docker-compose.prod.yml build
```

## License

MIT License - See the [LICENSE](LICENSE) file for details.

## Support

For support, please open an issue in the GitHub repository.
