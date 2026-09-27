# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-27  
**Status:** Google Drive Cloud Vault Integration, Offline SQLite Outbox Sync Worker, Google Drive Web Links, and Responsive Sync Activity Console (24/24 tests passing)

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers and async sync notifiers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.
- **Google Drive Cloud Vault Integration (`lib/data/remote/gdrive/` & `lib/features/sync/`):**
  - `GoogleDriveVaultService`: Multi-tier authentication supporting live Google OAuth2 (`google_sign_in` + `googleapis/drive/v3.dart`) and local sandbox mock fallback for zero-setup kiosk testing.
  - Automatic Folder Hierarchy: Provisions `/Dossier_Workspace/<Customer_Phone_Name>/<Case_ID_Title>/<Exhibits>` in Google Drive with parent folder linking.
  - Byte Streaming Upload: Native byte array and stream uploads with MIME type resolution and live progress callbacks (0-100%).
  - Direct Drive Web Viewer: Generates web links (`https://drive.google.com/file/d/<fileId>/view`) for exhibits and `https://drive.google.com/drive/folders/<folderId>` for workspace folders.
  - Outbox Sync Worker (`SyncNotifier` in `lib/features/sync/providers/sync_provider.dart`): Processes Drift SQLite `SyncQueue` mutations sequentially, uploads exhibits, persists remote IDs in `Exhibits.remoteFileId`, and transitions status to `SUCCESS` with retry tracking.
  - `VaultSyncScreen`: Google Drive account connection card, "Open in Drive" web launcher, live sync progress bar, storage plan switcher, Drift SQLite Outbox table, and terminal-style audit log console.
  - `ExhibitPreviewDialog`: Displays `DRIVE SYNCED` badge with file ID and 1-tap "Drive View" button.
- **Visual Design & Typography:**
  - Integrated `google_fonts` (Plus Jakarta Sans) with crisp weights, tailored line heights, and high-contrast letter spacing.
  - Refined Slate 900 / Slate 50 design system with Deep Indigo 500, Violet 500, and Emerald 500 accents.
- **Micro-Interactions & Animated Components:**
  - `DossierButton`: Animated iridescent rainbow border sweep (`LinearGradient` angle sweep + fade-in on hover), press-scale micro-feedback, and built-in contextual `Tooltip`.
  - `CollapsibleSidebar` (`lib/presentation/navigation/collapsible_sidebar.dart`): Animated collapsible sidebar (240px <-> 76px) with brand branding, active item indicator pills, operator profile card, theme mode switcher, and automatic hover tooltips in rail mode.
  - Material Architecture Fix: Wrapped `DossierDialog`, `DossierPanel`, and `DossierCard` in root `Material` containers to eliminate ListTile ink splash assertion exceptions.
- **POS & Billing Workflows (`lib/features/billing_pos/`):**
  - `QuickPosScreen`: Dynamically queries Drift SQLite `activeServicesStreamProvider` with category filters and search. Real invoices written to SQLite with 58mm thermal receipt preview.
  - `RecordPaymentDialog`: Custom amount, quick presets (`₹50`, `₹100`, `₹500`, `Full Due`), payment mode switching, and direct DB update of `Cases.advancePaid`.
  - `BillingHubPane`: Dynamic UPI QR code generator, 1-tap WhatsApp notifications, and thermal slip preview.
- **Test Suite (`test/widget_test.dart`):**
  - 24 comprehensive test suites passing with 0 warnings / 0 analyzer issues across desktop, tablet, and mobile breakpoints.

---

## 2. Commit History
- `[HEAD]`: `feat(ui): add rainbow hover border sweep to buttons, collapsible animated sidebar, and Google Fonts typography`
- `[PREV]`: `feat(ux): overhaul UI consistency, dynamic POS catalog, case notes, and direct payment workflows`
- `[PREV]`: `feat(attachments): implement real file picking, document preview, exhibit deletion, and zero-dummy-data clean state`
- `[PREV]`: `feat(auth): add offline-first Sign-In, Sign-Up, and Quick 4-Digit PIN unlock workflow with multi-operator switching`
- `eb7a9cc`: `fix(ui): ensure strict Material 3 compliance, fluid animation curves, and zero overflow layout across all resolutions`
- `e5d9dec`: `feat(ui): add animated splash screen, interactive micro-animations, and parameterized component library`
- `741a9b1`: `fix(responsive): eliminate layout overflows across mobile, tablet, and desktop viewports`
- `1d2c033`: `docs(memory): update memory tracker for Phase 3 completion`
- `c29f0c1`: `feat(settings): add Dark/Light theme toggle, collapsible Billing Hub, custom services catalog, and currency customizer`
- `94ae2af`: `docs(memory): update memory tracker for Phase 2 completion`
- `d21680d`: `feat(ui): build high-density 3-pane workstation, Media Prep Studio, Quick POS register, and Vault Sync monitor`
- `b06aa11`: `docs(memory): record Phase 1 commit history and current project state`
- `012b658`: `feat(ui): implement responsive Kiosk Workstation shell, test suite, and comprehensive README`
- `c8edd5f`: `feat(services): implement pure-Dart MediaPrepService, UPI QR, WhatsApp intents, and pluggable Vault connectors`
- `29bfedf`: `feat(db): declare Drift SQLite relational schema, DAOs, and generated type-safe database layer`
- `460db3a`: `feat(scaffold): initialize Flutter multiplatform project supporting Windows, Android, macOS, iOS, Linux, and Web`
- `61a6868`: `docs: add system HLD, tech spec, AGENTS.md ground rules, and memory tracker`
