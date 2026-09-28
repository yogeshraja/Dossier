# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-28  
**Status:** Global Country Code Selection, Unified Identifier & SMS OTP Sign-In Deployed & Verified (61/61 tests passing, 0 analyzer issues)

---

## 1. Project Overview & Architecture Decisions
- **Monorepo Layout:**
  - `apps/kiosk/`: Flutter 3.47.x (Dart 3.13.x) targeting Web (WASM), Desktop (Windows, macOS, Linux), and Mobile (Android, iOS).
  - `apps/web/`: Web marketing landing page & interactive documentation portal (Vite + Vanilla CSS/JS).
  - `services/api/`: Cloudflare Workers + D1 SQLite + Hono + Drizzle ORM serverless backend.
  - Root: `mise.toml` toolchain version manager and `package.json` task orchestration.

### Authentication & Country Code Architecture
1. **Global Country Code Selection & E.164 Formatting:**
   - Standardized `CountryCode` domain model with 27+ preloaded global countries (`IN`, `US`, `GB`, `CA`, `AE`, `SA`, `SG`, `MY`, `AU`, `DE`, `FR`, `BD`, `NP`, `LK`, `NG`, `ZA`, `PH`, `ID`, `KE`, `BR`, `JP`, etc.).
   - Interactive `DossierCountryPicker` dialog with live instant search by country name, ISO code, or dial code.
   - Built-in composite `DossierPhoneInputField` providing seamless flag + dial code prefix and country-specific digit placeholders.
   - Canonical E.164 number construction (`CountryCode.formatFullNumber()`) ensuring standardized phone storage and Twilio SMS verification across all regions.
2. **Unified Email / Mobile Identifier with Pattern Recognition:**
   - Single input field in Sign-In automatically detects whether the input is an email address (`@`) or mobile number (digits) and dynamically adjusts labels, hint text, and prefix icons.
   - Dispatches either `EmailPasswordAuthStrategy` or `PhonePasswordAuthStrategy` seamlessly.
3. **Dual Sign-In Modes (Password Default + SMS OTP Toggle):**
   - Password authentication remains the fast default.
   - Desk operators can switch to "Sign in with SMS OTP instead" using Twilio Verify v2 and `PhoneOtpAuthStrategy` (`POST /api/v1/auth/signin-otp`).
4. **Duplicate User Detection on Sign-Up:**
   - `POST /api/v1/auth/otp/send` with `purpose: "signup"` detects existing accounts and returns `HTTP 409 Conflict`.
   - UI gracefully surfaces the error with a one-tap **"Switch to Sign In →"** CTA that transitions to Sign-In mode and pre-fills the identifier.
5. **Modern Database Management & Dual-ID (`id` + `public_id`):**
   - **Internal Primary Key (`id`)**: `INTEGER PRIMARY KEY AUTOINCREMENT` for fast SQL joins.
   - **Public Identifier (`public_id`)**: `TEXT UNIQUE NOT NULL` for external API contracts and client sync.

### Customer-Facing UI Polish & Feature Tooltips
1. **Developer Jargon & Internal Protocol Removal:**
   - Replaced raw technical terms (`Twilio`, `Cloudflare D1`, `R2`, `SQLite/Drift Outbox`, `ESC/POS`, `DCT Quantization`, `Pure-Dart Background Isolates`) with customer-friendly terminology across all views, dialogs, badges, and snackbars.
   - Standardized terms: `SMS Verification`, `Cloud Backup Queue`, `Dossier Pro Cloud Vault`, `Thermal Receipt Printer`, `Attached Documents & Scans`, `Document Tools & Fast ID Prep`.
2. **Universal & Context-Rich Tooltips:**
   - Extended `DossierButton` to automatically supply standard tooltips matching button text whenever explicit tooltips are omitted, with zero extra boilerplate.
   - Added descriptive tooltips to country pickers, storage provider switches, search bars, navigation tabs, EOD closure receipts, and document management action chips.

### Single-Command Deployment
- `mise run deploy` (or `npm run deploy`):
  - Validates full monorepo test suite (61 Flutter tests + analyzer + Worker TypeScript check + Web portal build).
  - Automatically deploys the production Cloudflare Edge Worker with D1 bindings to `https://dossier-api.rajayogesh49.workers.dev`.

---

## 2. Testing & Quality Assurance
- **Flutter Kiosk Test Suite:** 61/61 unit, integration, and widget tests passing (100% pass rate).
- **Analyzer Status:** 0 errors, 0 warnings, 0 lints (`flutter analyze` clean).
- **Backend Status:** Cloudflare Workers TypeScript build clean (`tsc --noEmit`).
- **Live Health Endpoint:** `https://dossier-api.rajayogesh49.workers.dev/api/v1/auth/health` verified online.
