# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-26  
**Status:** Phase 1 (Core Foundation & Local Engine) Complete & Fully Verified

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.
- **Storage Tiering:**
  - **Free Tier:** BYO Google Drive API v3 (`drive.file` scope) chunked resumable upload ($0 infra cost).
  - **Pro Tier:** Cloudflare Workers + Cloudflare R2 (S3 presigned URLs, zero egress fees).
- **Peripherals:** Pure-Dart ESC/POS thermal printing (58mm/80mm), Dynamic UPI QR generator, WhatsApp intent deep links.
- **Media Engine:** Pure-Dart isolate-based ID stitching, DCT quantization target-size compression (<200KB / <50KB), 4x6 passport photo grid studio.

---

## 2. Completed Milestones & Files Created
1. **Design & Specifications:**
   - [dossier-hld.md](file:///home/yogesh/workspace/dossier/agentic/design/dossier-hld.md): High-Level Design document.
   - [dossier-tech-spec.md](file:///home/yogesh/workspace/dossier/agentic/design/dossier-tech-spec.md): Complete Technical Specification.
   - [AGENTS.md](file:///home/yogesh/workspace/dossier/AGENTS.md): AI agent ground rules and standards.
   - [README.md](file:///home/yogesh/workspace/dossier/README.md): Comprehensive project overview, features, and setup documentation.
2. **Project Scaffolding & Dependencies:**
   - Initialized Flutter multiplatform codebase.
   - Configured `pubspec.yaml` with Drift SQLite, Riverpod, Image/PDF, QR, and Cloud dependencies.
3. **Database Schemas & Generated DAOs:**
   - [schema.dart](file:///home/yogesh/workspace/dossier/lib/data/local/tables/schema.dart): Tables for `Dossiers`, `Services`, `Cases`, `CaseServices`, `Exhibits`, `Invoices`, `LedgerEntries`, and `SyncQueue`.
   - [app_database.dart](file:///home/yogesh/workspace/dossier/lib/data/local/app_database.dart): Drift database setup with reactive stream queries.
   - [app_database.g.dart](file:///home/yogesh/workspace/dossier/lib/data/local/app_database.g.dart): Successfully compiled and generated Drift code.
4. **Domain Services & Utilities:**
   - [vault_storage_service.dart](file:///home/yogesh/workspace/dossier/lib/domain/services/vault_storage_service.dart): Pluggable storage abstraction.
   - [google_drive_vault_service.dart](file:///home/yogesh/workspace/dossier/lib/data/remote/gdrive/google_drive_vault_service.dart): Free tier Google Drive v3 connector.
   - [managed_r2_vault_service.dart](file:///home/yogesh/workspace/dossier/lib/data/remote/r2/managed_r2_vault_service.dart): Pro tier Cloudflare R2 presigned connector.
   - [media_prep_service.dart](file:///home/yogesh/workspace/dossier/lib/domain/services/media_prep_service.dart): Background isolates for ID Stitcher, Portal Compressor, and 4x6 Passport Photo Grid.
   - [upi_qr_service.dart](file:///home/yogesh/workspace/dossier/lib/domain/services/upi_qr_service.dart): NPCI-compliant dynamic UPI QR string builder.
   - [whatsapp_notification_service.dart](file:///home/yogesh/workspace/dossier/lib/domain/services/whatsapp_notification_service.dart): Zero-cost WhatsApp alert deep-link launcher.
5. **UI Shell & Verification:**
   - [main.dart](file:///home/yogesh/workspace/dossier/lib/main.dart): Responsive Kiosk Workstation shell with modern dark theme and adaptive navigation.
   - `flutter analyze`: **0 issues found**.
   - `flutter test`: **All tests passing**.

---

## 3. Next Actions
- [ ] Connect Drift SQLite DAOs to Riverpod state notifiers.
- [ ] Implement the Customer Intake modal & Quick Walk-in form.
- [ ] Build the interactive Media Prep Studio UI (Camera/File capture -> ID Stitcher / Portal Compressor preview).
