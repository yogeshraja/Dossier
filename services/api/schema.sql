-- Dossier Cloudflare D1 (SQLite) Schema Migration
-- Dual-ID Pattern:
-- 1. `id`: INTEGER PRIMARY KEY AUTOINCREMENT (Fast internal index, sequential rowid, easy SQL queries)
-- 2. `public_id`: TEXT UNIQUE NOT NULL (Opaque, tamper-proof, public API & sync identifier)

DROP TABLE IF EXISTS cases;
DROP TABLE IF EXISTS dossiers;
DROP TABLE IF EXISTS sync_items;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS otp_verifications;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS kiosks;

CREATE TABLE kiosks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    public_id TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    owner_public_id TEXT NOT NULL,
    address TEXT,
    phone TEXT,
    upi_vpa TEXT,
    license_key TEXT UNIQUE,
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'suspended', 'deleted'
    is_active INTEGER NOT NULL DEFAULT 1,
    is_suspended INTEGER NOT NULL DEFAULT 0,
    suspended_at TEXT,
    suspended_reason TEXT,
    deleted_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    public_id TEXT NOT NULL UNIQUE,
    kiosk_public_id TEXT,
    name TEXT NOT NULL,
    email TEXT,
    mobile TEXT,
    is_mobile_verified INTEGER NOT NULL DEFAULT 0,
    role TEXT NOT NULL DEFAULT 'operator', -- 'admin', 'manager', 'operator'
    pin_hash TEXT NOT NULL,
    password_hash TEXT,
    auth_provider TEXT DEFAULT 'local', -- 'email', 'mobile', 'google', 'local'
    google_id TEXT,
    avatar_url TEXT,
    status TEXT NOT NULL DEFAULT 'active', -- 'active', 'suspended', 'deleted'
    is_active INTEGER NOT NULL DEFAULT 1,
    is_suspended INTEGER NOT NULL DEFAULT 0,
    suspended_at TEXT,
    suspended_reason TEXT,
    deleted_at TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE otp_verifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    public_id TEXT NOT NULL UNIQUE,
    mobile TEXT NOT NULL,
    otp_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    is_verified INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);

CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    public_id TEXT NOT NULL UNIQUE,
    user_public_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE sync_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    public_id TEXT NOT NULL UNIQUE,
    user_public_id TEXT NOT NULL,
    kiosk_public_id TEXT,
    entity_type TEXT NOT NULL, -- 'customer', 'case', 'exhibit', 'transaction'
    entity_id TEXT NOT NULL,
    action TEXT NOT NULL,      -- 'create', 'update', 'delete'
    payload TEXT NOT NULL,     -- JSON stringified mutation
    client_timestamp TEXT NOT NULL,
    server_timestamp TEXT NOT NULL
);

CREATE TABLE dossiers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    public_id TEXT NOT NULL UNIQUE,
    user_public_id TEXT NOT NULL,
    kiosk_public_id TEXT,
    full_name TEXT NOT NULL,
    mobile TEXT,
    aadhaar_ref TEXT,
    pan_ref TEXT,
    metadata_json TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE cases (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    public_id TEXT NOT NULL UNIQUE,
    dossier_public_id TEXT NOT NULL,
    user_public_id TEXT NOT NULL,
    kiosk_public_id TEXT,
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'intake',
    total_amount REAL NOT NULL DEFAULT 0.0,
    paid_amount REAL NOT NULL DEFAULT 0.0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

-- Performance Indexes
CREATE INDEX idx_kiosks_public_id ON kiosks(public_id);
CREATE INDEX idx_kiosks_owner ON kiosks(owner_public_id);
CREATE INDEX idx_kiosks_status ON kiosks(status);

CREATE INDEX idx_users_public_id ON users(public_id);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_mobile ON users(mobile);
CREATE INDEX idx_users_kiosk ON users(kiosk_public_id);
CREATE INDEX idx_users_status ON users(status);

CREATE INDEX idx_otp_mobile ON otp_verifications(mobile);
CREATE INDEX idx_otp_expires ON otp_verifications(expires_at);

CREATE INDEX idx_sessions_token ON sessions(token);
CREATE INDEX idx_sessions_user ON sessions(user_public_id);

CREATE INDEX idx_sync_user_time ON sync_items(user_public_id, server_timestamp);
CREATE INDEX idx_sync_kiosk_time ON sync_items(kiosk_public_id, server_timestamp);

CREATE INDEX idx_dossiers_user ON dossiers(user_public_id);
CREATE INDEX idx_dossiers_mobile ON dossiers(mobile);

CREATE INDEX idx_cases_dossier ON cases(dossier_public_id);
CREATE INDEX idx_cases_status ON cases(status);
