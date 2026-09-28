# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-28  
**Status:** Two-Tier Operator Authentication, Software Activation Gate & Web-First Architecture Completed & Verified (42/42 tests passing, 0 analyzer issues)

---

## 1. Project Overview & Architecture Decisions
- **Monorepo Layout:**
  - `apps/kiosk/`: Flutter 3.47.x (Dart 3.13.x) targeting Web (WASM), Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
  - `services/api/`: Cloudflare Workers + D1 SQLite + Hono serverless backend.
  - Root: `mise.toml` toolchain version manager and `package.json` task orchestration.

### OOP Authentication Strategy & Multi-Step Kiosk Registration Flow
1. **Inheritance-Based Auth Strategy Hierarchy:**
   - Base interface `AuthStrategy` and abstract base class `BaseAuthStrategy` with template validation & execution.
   - Specific implementations: `EmailPasswordAuthStrategy`, `PhonePasswordAuthStrategy`, and `GoogleSsoAuthStrategy` (Google SSO).
   - Resolved via `AuthStrategyFactory`.
2. **Step 1: User Login / Sign-Up:**
   - App opens with user authentication screen supporting Email/Password, Mobile/Password, and Google SSO.
3. **Step 2: Kiosk Product Registration & Activation:**
   - Once authenticated as Admin, if the kiosk is not yet registered on the device, user completes Kiosk Center Name, Address, Merchant UPI VPA, and 4-digit Master PIN.
   - Dispatches `/api/v1/auth/kiosk/register` to Cloudflare D1 edge backend and unlocks full CRM/POS capabilities.
4. **Step 3: Daily Desk Operator Shift PIN Login:**
   - Staff switch between operator avatars with 4-digit touch PINs.

---

## 2. Testing & Quality Assurance
- **Total Tests:** 43/43 unit, integration, and widget tests passing (100% pass rate).
  - `apps/kiosk/test/auth_server_test.dart` (4 tests: email strategy, phone strategy, Google SSO strategy, full login -> kiosk registration -> shift login flow).
  - `apps/kiosk/test/modernization_test.dart` (9 tests: glassmorphism, command palette, sparklines, thermal receipt).
  - `apps/kiosk/test/widget_test.dart` (30 tests: responsive layout breakpoints from 320px to 1440px with 0 RenderFlex overflows).
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
