# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-26  
**Status:** Phase 1 Complete & Cleanly Committed

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

## 2. Commit History
- `61a6868`: `docs: add system HLD, tech spec, AGENTS.md ground rules, and memory tracker`
- `460db3a`: `feat(scaffold): initialize Flutter multiplatform project supporting Windows, Android, macOS, iOS, Linux, and Web`
- `29bfedf`: `feat(db): declare Drift SQLite relational schema, DAOs, and generated type-safe database layer`
- `c8edd5f`: `feat(services): implement pure-Dart MediaPrepService, UPI QR, WhatsApp intents, and pluggable Vault connectors`
- `012b658`: `feat(ui): implement responsive Kiosk Workstation shell, test suite, and comprehensive README`

---

## 3. Next Actions (Phase 2)
- [ ] Connect Drift SQLite DAOs to Riverpod state notifiers.
- [ ] Implement the Customer Intake modal & Quick Walk-in form.
- [ ] Build the interactive Media Prep Studio UI (Camera/File capture -> ID Stitcher / Portal Compressor preview).
