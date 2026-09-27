# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-27  
**Status:** Real Attachment Workflows, Document Previews & Deletions, Media Prep File Processing, and Zero-Dummy-Data Architecture Implemented & Verified (23/23 tests passing)

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.
- **Zero Dummy Data Architecture:**
  - Removed all hardcoded mock customers, cases, and operators from initial database seeders.
  - Added `InitialDataSeeder.cleanDummyData()` to purge any legacy mock data.
  - Replaced hardcoded form strings with clean empty states prompting real operator input and first-time kiosk setup.
- **Attachment & Document Management Workflows:**
  - `AttachDocumentDialog` (`lib/features/cases/widgets/attach_document_dialog.dart`): Real multi-file picker via `FilePicker` (JPG, PNG, PDF, WebP, BMP, TIFF), document slot classifier (Aadhaar Front/Back, Passport Photo, PAN Card, Income Certificate, Signature, etc.), live file size formatting, and batch database insertion.
  - `ExhibitPreviewDialog` (`lib/features/cases/widgets/exhibit_preview_dialog.dart`): Interactive document viewer supporting image zoom/pan (`InteractiveViewer`), PDF document cards, external system file launch via `url_launcher`, and permanent deletion from SQLite.
  - `CaseIntakePane` (`lib/features/cases/widgets/case_intake_pane.dart`): Real local file thumbnails and interactive attachment triggers.
- **Media Prep Studio (`lib/features/media_prep/screens/media_prep_studio_screen.dart`):**
  - Integrated real `FilePicker` into ID Card Stitcher (Front & Back card picks), DCT Quantized Compressor (target KB bounds), and Passport Photo Grid generator.
  - Background isolate compute via pure Dart (`MediaPrepService`) for seamless 60fps rendering.
- **Authentication & Multi-Operator Workflow (`lib/features/auth/`):**
  - `KioskOperator` model: Encapsulates operator profile, assigned role (`admin`, `manager`, `operator`), phone/email identifier, password, 4-digit PIN, and kiosk center details.
  - `authProvider` (`AuthNotifier`): Offline-first authentication controller supporting password sign-in, quick 4-digit PIN unlock, new kiosk registration (onboarding), operator session locking.
  - `AuthScreen` (`lib/features/auth/screens/auth_screen.dart`): Material Design 3 responsive auth interface with fluid tab transitions between Operator Sign-In and New Kiosk Setup.
- **Component Design System (`lib/presentation/common_widgets/`):**
  - `DossierButton`, `DossierCard`, `DossierInputField`, `DossierPanel`, `DossierBadge`, `DossierDialog`.
- **Test Suite (`test/widget_test.dart`):**
  - 23 comprehensive test suites verifying Splash boot sequence, multi-resolution responsiveness (Desktop 1440px, Tablet 768px, Mobile 390px, Small Screen 320px), component interactions, Auth flows, Attachment Dialogs, and Exhibit Previews with zero RenderFlex overflows.

---

## 2. Commit History
- `[HEAD]`: `feat(attachments): implement real file picking, document preview, exhibit deletion, and zero-dummy-data clean state`
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
