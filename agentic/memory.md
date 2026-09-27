# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-27  
**Status:** Remote Server Authentication, Account Sign-Up & Sync Integration Completed & Verified (39/39 tests passing, 0 analyzer issues)

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers and async sync notifiers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.

### Server Authentication & Multi-Tier Sync Engine
1. **Remote Server Auth API (`lib/data/remote/auth/server_auth_api_service.dart`):**
   - Direct HTTP client integrating `POST /api/v1/auth/signup`, `POST /api/v1/auth/signin`, and `POST /api/v1/auth/verify-pin`.
   - Creates operator accounts and kiosk business tenants on remote server backend.
   - Issues JWT session authentication tokens stored in state and synchronized to local storage.
   - Transparent offline fallback: automatically caches accounts locally so operators can log in or unlock via PIN even during internet downtime.

2. **Auth Notifier Integration (`lib/features/auth/providers/auth_provider.dart`):**
   - Coordinates remote server sign-up, password sign-in, and 4-digit PIN unlock.
   - Synchronizes kiosk business metadata (business name, address, phone, merchant UPI VPA) across KioskSettings and remote profile.
   - Live server connectivity indicator (`isServerConnected`, `serverUrl`, `isOfflineMode`).

3. **Interactive Auth Screen (`lib/features/auth/screens/auth_screen.dart`):**
   - Segmented Sign-In vs. New Kiosk Setup views with live server status pill.
   - Password vs. 4-digit touch PIN numpad toggle.

---

## 2. Testing & Quality Assurance
- **Total Tests:** 39/39 unit, integration, and widget tests passing (100% pass rate).
  - 4 dedicated server auth & offline fallback tests in `test/auth_server_test.dart`.
  - 9 modernization pillar widget tests in `test/modernization_test.dart`.
  - 26 multi-resolution & feature workflow tests in `test/widget_test.dart`.
- **Analyzer Status:** 0 errors, 0 warnings, 0 lints.
- **Responsiveness:** Validated on viewport widths from 320px mobile up to 1440px multi-pane desktop workstation with 0 RenderFlex overflows.

---

## 3. Commit History
- `[HEAD]`: `feat(auth): integrate ServerAuthApiService for remote account sign-up, JWT session sync, and resilient offline cache fallback`
- `[PREV]`: `fix(linux): suppress Mesa/EGL virtual DRI fallback logs and configure default Adwaita GTK cursor theme`
- `[PREV]`: `feat(modernization): add CaseStageTimeline, ambient KioskStatusBar, smart Dossier filters, and floating DossierToast notifications`
- `[PREV]`: `feat(modernization): implement 5-pillar UI overhaul with glassmorphism, Ctrl+K command palette, quick cash tender pad, animated thermal receipts, and sparkline charts`
- `[PREV]`: `feat(printing): add ESC/POS raw hardware byte driver, Daily Sales register, and Cloudflare R2 backup vault`
- `[PREV]`: `feat(ui): add rainbow hover border sweep to buttons, collapsible animated sidebar, and Google Fonts typography`
- `[PREV]`: `feat(ux): overhaul UI consistency, dynamic POS catalog, case notes, and direct payment workflows`
- `[PREV]`: `feat(attachments): implement real file picking, document preview, exhibit deletion, and zero-dummy-data clean state`
- `[PREV]`: `feat(auth): add offline-first Sign-In, Sign-Up, and Quick 4-Digit PIN unlock workflow with multi-operator switching`
