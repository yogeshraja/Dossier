# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-28  
**Status:** Drizzle ORM Schema Management & Dual-ID Pattern Deployed & Verified (56/56 tests passing, 0 analyzer issues)

---

## 1. Project Overview & Architecture Decisions
- **Monorepo Layout:**
  - `apps/kiosk/`: Flutter 3.47.x (Dart 3.13.x) targeting Web (WASM), Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
  - `apps/web/`: Web marketing landing page & interactive documentation portal (Vite + Vanilla CSS/JS).
  - `services/api/`: Cloudflare Workers + D1 SQLite + Hono + Drizzle ORM serverless backend.
  - Root: `mise.toml` toolchain version manager and `package.json` task orchestration.

### Modern Database Management & Schema Architecture
1. **Drizzle ORM for Cloudflare D1:**
   - Replaced fragile manual raw SQL with **TypeScript-first schema definitions** in `services/api/src/db/schema.ts`.
   - Automated migration generation with `drizzle-kit generate` (producing versioned SQL migrations in `drizzle/migrations/`).
   - Visual database inspection via `npm run db:studio`.
2. **Dual-ID Pattern (`id` + `public_id`):**
   - **Internal Primary Key (`id`)**: `INTEGER PRIMARY KEY AUTOINCREMENT` for native B-Tree sequential rowid locality, compact foreign keys, and fast SQL debugging (`SELECT * FROM users WHERE id = 1`).
   - **Public Identifier (`public_id`)**: `TEXT UNIQUE NOT NULL` (e.g. `usr_...`, `ksk_...`) for external API contracts, JWT session tokens, and outbox sync, preventing IDOR attacks and hiding business volume metrics.

### Single-Command Deployment
- `mise run deploy` (or `npm run deploy`):
  - Validates full monorepo test suite (56 Flutter tests + analyzer + Worker TypeScript check + Web portal build).
  - Automatically deploys the production Cloudflare Edge Worker with D1 bindings to `https://dossier-api.rajayogesh49.workers.dev`.

---

## 2. Testing & Quality Assurance
- **Flutter Kiosk Test Suite:** 56/56 unit, integration, and widget tests passing (100% pass rate).
- **Analyzer Status:** 0 errors, 0 warnings, 0 lints (`flutter analyze` clean).
- **Backend Status:** Cloudflare Workers TypeScript build clean (`tsc --noEmit`).
- **Live Health Endpoint:** Verified online with `databaseSchema: "Dual-ID (Integer PK + Public UUID)"`.
