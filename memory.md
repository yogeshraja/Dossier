# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-28  
**Status:** Two-Tier Operator Authentication, Software Activation Gate & Web-First Architecture Completed & Verified (42/42 tests passing, 0 analyzer issues)

---

## 1. Project Overview & Architecture Decisions
- **Monorepo Layout:**
  - `apps/kiosk/`: Flutter 3.47.x (Dart 3.13.x) targeting Web (WASM), Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
  - `services/api/`: Cloudflare Workers + D1 SQLite + Hono serverless backend.
  - Root: `mise.toml` toolchain version manager and `package.json` task orchestration.

### Two-Tier Operator Authentication & Software Activation Gate
1. **Tier 1 (Admin Software Activation):**
   - Software starts unactivated/locked.
   - Master Admin logs in or registers on the remote Cloudflare backend (`/api/v1/auth/activate`).
   - Activation establishes master kiosk identity, stores cloud tenant credentials, and unlocks app features.
2. **Tier 2 (Operator Shift PIN Login):**
   - Once activated, counter staff switch and log in quickly with 4-digit PINs (`/api/v1/auth/operator-login`).
   - Admin can provision new operators (`/api/v1/auth/operators`), synced directly to Cloudflare D1 and cached locally in Drift SQLite for instant offline availability.
3. **Web-First Design & Progressive Local Enhancement Mandate:**
   - App UI and interaction flows are designed web-first (WASM + OPFS).
   - Desktop and Mobile native builds function as progressive enhancements utilizing native C-FFI SQLite drivers, direct raw ESC/POS thermal printer byte buffers, and background Dart isolates.

---

## 2. Testing & Quality Assurance
- **Total Tests:** 42/42 unit, integration, and widget tests passing (100% pass rate).
  - `apps/kiosk/test/auth_server_test.dart` (3 tests: activation, operator provisioning, shift PIN login).
  - `apps/kiosk/test/modernization_test.dart` (9 tests: glassmorphism, command palette, sparklines, thermal receipt).
  - `apps/kiosk/test/widget_test.dart` (30 tests: responsive layout breakpoints from 320px to 1440px, workflows).
- **Analyzer Status:** 0 errors, 0 warnings, 0 lints (`flutter analyze` clean).
- **Backend Status:** Cloudflare Workers TypeScript build clean (`tsc --noEmit`).

---

## 3. Toolchain & Task Automation (`mise.toml`)
- `node = "26"`, `flutter = "3.47"`.
- `mise run test:all` -> runs backend TypeScript check + Flutter unit & widget tests + Web docs build.
- `mise run dev:api` -> starts local Cloudflare Wrangler dev server.
- `mise run dev:web` -> starts local Vite docs & marketing portal server.
- `mise run dev:kiosk` -> launches Flutter Web in Chrome.

---

## 4. Commit History
- `[HEAD] 1a8a048`: `feat(web,auth): add docs website portal, software activation gate & two-tier operator auth`
