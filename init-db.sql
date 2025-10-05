-- Database schema for PHP Platform
-- This script initializes the SQLite database with required tables

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Applications table
CREATE TABLE IF NOT EXISTS apps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    domain TEXT NOT NULL UNIQUE,
    git_uri TEXT NOT NULL,
    public_key TEXT,
    path TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- API keys for authentication
CREATE TABLE IF NOT EXISTS api_keys (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    key_hash TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

-- Deployment history
CREATE TABLE IF NOT EXISTS deployments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    app_id INTEGER NOT NULL,
    commit_hash TEXT,
    commit_message TEXT,
    status TEXT NOT NULL,
    output TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (app_id) REFERENCES apps (id) ON DELETE CASCADE
);

-- System settings
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    description TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default settings
INSERT OR IGNORE INTO settings (key, value, description) VALUES
    ('admin_email', 'admin@example.com', 'Administrator email for notifications'),
    ('backup_retention_days', '7', 'Number of days to keep backups'),
    ('default_php_version', '8.2', 'Default PHP version for new apps'),
    ('max_upload_size', '64M', 'Maximum file upload size'),
    ('timezone', 'Europe/Warsaw', 'Default timezone');

-- Create an index for faster lookups
CREATE INDEX IF NOT EXISTS idx_apps_domain ON apps(domain);
CREATE INDEX IF NOT EXISTS idx_deployments_app_id ON deployments(app_id);

-- Create a view for application status
CREATE VIEW IF NOT EXISTS v_app_status AS
SELECT 
    a.id,
    a.name,
    a.domain,
    a.status,
    d.commit_hash,
    d.commit_message,
    d.created_at as last_deployed,
    (SELECT COUNT(*) FROM deployments WHERE app_id = a.id) as deployment_count
FROM 
    apps a
LEFT JOIN 
    deployments d ON d.id = (SELECT id FROM deployments WHERE app_id = a.id ORDER BY created_at DESC LIMIT 1);

-- Create a trigger to update the updated_at timestamp
CREATE TRIGGER IF NOT EXISTS update_apps_timestamp
AFTER UPDATE ON apps
BEGIN
    UPDATE apps SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Create a default admin API key (replace 'default-key' with a secure key in production)
-- This is for development only
INSERT OR IGNORE INTO api_keys (name, key_hash) 
VALUES ('Default Admin', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8'); -- 'password' hashed with SHA-256
