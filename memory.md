# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-26  
**Status:** Phase 2 (High-Density 3-Pane Workstation, Media Studio, POS & Sync) Complete & Tested

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.
- **Storage Tiering:**
  - **Free Tier:** BYO Google Drive API v3 (`drive.file` scope) chunked resumable upload ($0 infra cost).
  - **Pro Tier:** Cloudflare Workers + Cloudflare R2 (S3 presigned URLs, zero egress fees).
- **Peripherals:** Pure-Dart ESC/POS thermal printing (58mm/80mm), Dynamic UPI QR generator, WhatsApp intent deep links.
- **Media Engine:** Pure-Dart isolate-based ID stitching, DCT quantization target-size compression (<200KB / <50KB), 4x6 passport photo grid studio.

---

## 2. Commit History
- `d21680d`: `feat(ui): build high-density 3-pane workstation, Media Prep Studio, Quick POS register, and Vault Sync monitor`
- `b06aa11`: `docs(memory): record Phase 1 commit history and current project state`
- `012b658`: `feat(ui): implement responsive Kiosk Workstation shell, test suite, and comprehensive README`
- `c8edd5f`: `feat(services): implement pure-Dart MediaPrepService, UPI QR, WhatsApp intents, and pluggable Vault connectors`
- `29bfedf`: `feat(db): declare Drift SQLite relational schema, DAOs, and generated type-safe database layer`
- `460db3a`: `feat(scaffold): initialize Flutter multiplatform project supporting Windows, Android, macOS, iOS, Linux, and Web`
- `61a6868`: `docs: add system HLD, tech spec, AGENTS.md ground rules, and memory tracker`

---

## 3. Implemented Workstation Features & Screens
1. **Dossiers & Intake Workstation (3-Pane Adaptive Split):**
   - **Left Pane (`DossierListPane`):** Live customer search, phone lookup, quick add modal (`NewDossierDialog`), active customer selection.
   - **Center Pane (`CaseIntakePane`):** Customer profile banner, multi-case tabs, 6-stage lifecycle stepper (`DRAFT` → `CLOSED`), financial stats overview, exhibits slot manager.
   - **Right Pane (`BillingHubPane`):** Dynamic NPCI UPI QR code, 1-tap WhatsApp alert triggers (pickup notification & missing documents request), 58mm thermal receipt paper preview.
2. **Interactive Media Prep Studio (`MediaPrepStudioScreen`):**
   - **ID Card Front/Back Stitcher:** Vertical merging onto A4/ID canvas with fold & cut guidelines.
   - **Portal Target-Size Compressor:** Binary-search DCT quantization (< 200 KB & < 50 KB).
   - **4×6 Passport Photo Grid Studio:** Auto-cropping to 35×45mm with 6-photo (2×3) or 8-photo (2×4) tiled sheet.
3. **Walk-in POS Counter (`QuickPosScreen`):**
   - 1-Tap sales register for Xerox, Printouts, Lamination, Photo sets with live cart, instant UPI QR, cash payment logging, and receipt printing.
4. **Cloud Vault & Sync Monitor (`VaultSyncScreen`):**
   - Real-time `SyncQueue` outbox table monitoring, Free Tier (BYO Drive) vs Pro Tier (Cloudflare R2) switcher, and force cloud sync actions.
