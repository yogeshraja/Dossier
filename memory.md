# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-28  
**Status:** Admin-Only Operator Provisioning & Dedicated User Settings Page Implemented & Verified (40/40 tests passing, 0 analyzer issues)

---

## 1. Project Overview & Architecture Decisions
- **Monorepo Layout:**
  - `apps/kiosk/`: Flutter 3.47.x (Dart 3.13.x) targeting Web (WASM), Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
  - `apps/web/`: Web marketing landing page & interactive documentation portal (Vite + Vanilla CSS/JS).
  - `services/api/`: Cloudflare Workers + D1 SQLite + Hono serverless backend.
  - Root: `mise.toml` toolchain version manager and `package.json` task orchestration.

### Dedicated User Profile & Admin-Only Operator Management
1. **Admin-Only Operator Access Gate:**
   - Only operators with `OperatorRole.admin` (or verified master kiosk credentials) are authorized to provision, edit, and deactivate desk operators.
   - On the Shift PIN Screen, clicking "Add Operator" triggers a Master Admin PIN authorization modal before unlocking operator creation.
   - In `SettingsScreen`, the "Team & Operators" tab is strictly restricted to Administrators (displaying a secure shield lock for standard operators).
2. **Dedicated User Settings & Profile Hub for Each Operator:**
   - Every operator has a dedicated **"My Profile"** settings tab:
     - Profile Identity & Role overview with avatar badge.
     - Profile details editor (Full Name, Phone number, Email address).
     - Security & Credentials: Change 4-digit PIN with active PIN validation.
     - Workplace & POS Hardware Defaults (Receipt width 58mm/80mm, Auto-cut pulse, Operator name on receipt, Sound & haptic feedback).
     - Session control (End Shift / Switch Operator / Sign Out Account).

---

## 2. Testing & Quality Assurance
- **Total Tests:** 40/40 unit, integration, and widget tests passing (100% pass rate).
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
