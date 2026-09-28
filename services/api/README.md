# Dossier Cloudflare Edge API (Workers + D1 SQLite)

High-performance, zero-cost serverless backend for **Dossier** (Kiosk Vault & Touch POS).

## Features
- **Cloudflare Workers**: Ultra-low latency edge compute with 0 cold starts.
- **Cloudflare D1 (SQLite)**: Serverless SQLite database mirroring Dossier's local Drift SQLite schema.
- **WebCrypto Auth**: High-security PBKDF2 PIN hashing and JWT session tokens.
- **Outbox Sync API**: Direct batch synchronization for offline mutations.
- **Free Tier Ready**: 100,000 requests/day, 5 GB D1 database storage, $0 egress fees.

---

## 🚀 Quick Start (Local Development)

1. Navigate to the backend directory and install dependencies:
   ```bash
   cd backend
   npm install
   ```

2. Initialize local D1 SQLite database:
   ```bash
   npx wrangler d1 execute dossier-db --local --file=./schema.sql
   ```

3. Start local development server (runs at `http://127.0.0.1:8787`):
   ```bash
   npm run dev
   ```

---

## 🌐 1-Click Cloudflare Deployment

1. **Log in to Cloudflare** (first time only):
   ```bash
   npx wrangler login
   ```

2. **Create your free D1 Database on Cloudflare**:
   ```bash
   npx wrangler d1 create dossier-db
   ```
   *Copy the generated `database_id` and paste it into `wrangler.toml` under `database_id`.*

3. **Apply the SQLite schema to your remote database**:
   ```bash
   npm run db:init:remote
   ```

4. **Deploy to production**:
   ```bash
   npm run deploy
   ```

Once deployed, Wrangler will output your live URL (e.g., `https://dossier-api.<your-name>.workers.dev`).

---

## 📡 API Endpoints

### Auth
- `GET  /api/v1/auth/health` — Edge server status and latency timestamp
- `POST /api/v1/auth/signup` — Create a new kiosk operator account
- `POST /api/v1/auth/signin` — Authenticate operator & receive 30-day JWT
- `POST /api/v1/auth/verify-pin` — 4-digit PIN verification for quick desk unlock

### Sync
- `POST /api/v1/sync/push` — Batch push offline mutations from Drift `SyncQueue`
- `GET  /api/v1/sync/pull` — Pull remote mutations since timestamp
