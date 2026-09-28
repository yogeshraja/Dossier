-- Dossier Cloudflare D1 (SQLite) Schema

CREATE TABLE IF NOT EXISTS kiosks (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    upi_vpa TEXT,
    license_key TEXT UNIQUE,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    kiosk_id TEXT,
    name TEXT NOT NULL,
    email TEXT,
    mobile TEXT,
    role TEXT NOT NULL DEFAULT 'operator', -- 'admin', 'manager', 'operator'
    pin_hash TEXT NOT NULL,
    password_hash TEXT,
    auth_provider TEXT DEFAULT 'local', -- 'email', 'mobile', 'google', 'local'
    google_id TEXT,
    avatar_url TEXT,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (kiosk_id) REFERENCES kiosks(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS sync_items (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    kiosk_id TEXT,
    entity_type TEXT NOT NULL, -- 'customer', 'case', 'exhibit', 'transaction'
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL,      -- 'create', 'update', 'delete'
    payload TEXT NOT NULL,     -- JSON stringified mutation
    client_timestamp TEXT NOT NULL,
    server_timestamp TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS dossiers (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    kiosk_id TEXT,
    full_name TEXT NOT NULL,
    mobile TEXT,
    aadhaar_ref TEXT,
    pan_ref TEXT,
    metadata_json TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS cases (
    id TEXT PRIMARY KEY,
    dossier_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    kiosk_id TEXT,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'intake',
    total_amount REAL NOT NULL DEFAULT 0.0,
    paid_amount REAL NOT NULL DEFAULT 0.0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY (dossier_id) REFERENCES dossiers(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id TEXT PRIMARY KEY,
    kiosk_id TEXT,
    user_id TEXT,
    action TEXT NOT NULL,
    details TEXT,
    ip_address TEXT,
    created_at TEXT NOT NULL
);

-- Indices for performance
CREATE INDEX IF NOT EXISTS idx_users_kiosk ON users(kiosk_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token);
CREATE INDEX IF NOT EXISTS idx_sync_items_kiosk ON sync_items(kiosk_id, server_timestamp);
CREATE INDEX IF NOT EXISTS idx_cases_dossier ON cases(dossier_id);
