# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-27  
**Status:** End-to-End Flow & UI Overhaul Complete: Dynamic Services POS, Real Payments & SQLite Sync, Case Notes, Media Prep Direct Attachment, Refined Palette & Micro-Animations (24/24 tests passing)

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.
- **Visual Design & Palette:**
  - Refined Slate 900 / Slate 50 design system with Deep Indigo 500, Violet 500, and Emerald 500 accents.
  - Hover micro-animations, input focus glow rings, high-contrast typography, and fluid state transitions across all panes.
- **Zero Dummy Data Architecture:**
  - Removed all hardcoded mock customers, cases, and operators from initial database seeders.
  - Added `InitialDataSeeder.cleanDummyData()` to purge legacy mock data.
  - Replaced hardcoded form strings with clean empty states prompting real operator input and first-time kiosk setup.
- **POS & Billing Workflows (`lib/features/billing_pos/`):**
  - `QuickPosScreen`: Dynamically queries Drift SQLite `activeServicesStreamProvider` with category filters (Printing, Govt Scheme, Certificate, Utility, Legal, Financial) and search. Generates real invoices into SQLite `Invoices` table with 58mm thermal receipt preview.
  - `RecordPaymentDialog`: Custom amount, quick presets (`₹50`, `₹100`, `₹500`, `Full Due`), payment mode switching (`CASH`, `UPI`, `CARD`), and direct DB update of `Cases.advancePaid`.
  - `BillingHubPane`: Live UPI QR code generator and trigger for payment collection.
- **Case Management & Intake (`lib/features/cases/`):**
  - Customer remarks & instructions panel with real-time SQLite sync.
  - Case and Dossier deletion with confirmation dialogs.
  - Financial overview card with direct payment collection shortcut.
- **Attachment & Document Management Workflows:**
  - `AttachDocumentDialog` (`lib/features/cases/widgets/attach_document_dialog.dart`): Real multi-file picker via `FilePicker` (JPG, PNG, PDF, WebP, BMP, TIFF), document slot classifier, live file size formatting, and batch database insertion.
  - `ExhibitPreviewDialog` (`lib/features/cases/widgets/exhibit_preview_dialog.dart`): Interactive document viewer supporting image zoom/pan (`InteractiveViewer`), PDF document cards, external system file launch via `url_launcher`, and permanent deletion from SQLite.
- **Media Prep Studio (`lib/features/media_prep/screens/media_prep_studio_screen.dart`):**
  - Real `FilePicker` for ID Card Stitcher, DCT Quantized Compressor, and Passport Photo Grid generator.
  - Direct 1-click attachment of processed media into the active case's exhibits in Drift SQLite.
- **Test Suite (`test/widget_test.dart`):**
  - 24 comprehensive test suites verifying Splash boot sequence, multi-resolution responsiveness, component interactions, Auth flows, Attachment Dialogs, Record Payment Dialog, and Quick POS screens with zero RenderFlex overflows.

---

## 2. Commit History
- `[HEAD]`: `feat(ux): overhaul UI consistency, dynamic POS catalog, case notes, and direct payment workflows`
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
