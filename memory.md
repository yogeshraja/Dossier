# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-26  
**Status:** Phase 3 (Dark/Light Themes, Collapsible Billing Hub, Custom Services Catalog & Currency Configuration) Complete & Tested

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.
- **Storage Tiering:**
  - **Free Tier:** BYO Google Drive API v3 (`drive.file` scope) chunked resumable upload ($0 infra cost).
  - **Pro Tier:** Cloudflare Workers + Cloudflare R2 (S3 presigned URLs, zero egress fees).
- **Theme & Customization:** Full Dark & Light Themes with instant 1-tap switcher, user-configurable currency symbols (`₹`, `$`, `€`, `£`, `AED`, etc.), and custom services editor.

---

## 2. Commit History
- `c29f0c1`: `feat(settings): add Dark/Light theme toggle, collapsible Billing Hub, custom services catalog, and currency customizer`
- `94ae2af`: `docs(memory): update memory tracker for Phase 2 completion`
- `d21680d`: `feat(ui): build high-density 3-pane workstation, Media Prep Studio, Quick POS register, and Vault Sync monitor`
- `b06aa11`: `docs(memory): record Phase 1 commit history and current project state`
- `012b658`: `feat(ui): implement responsive Kiosk Workstation shell, test suite, and comprehensive README`
- `c8edd5f`: `feat(services): implement pure-Dart MediaPrepService, UPI QR, WhatsApp intents, and pluggable Vault connectors`
- `29bfedf`: `feat(db): declare Drift SQLite relational schema, DAOs, and generated type-safe database layer`
- `460db3a`: `feat(scaffold): initialize Flutter multiplatform project supporting Windows, Android, macOS, iOS, Linux, and Web`
- `61a6868`: `docs: add system HLD, tech spec, AGENTS.md ground rules, and memory tracker`

---

## 3. Implemented Workstation Features & Screens
1. **Adaptive Theme Engine ([`theme.dart`](file:///home/yogesh/workspace/dossier/lib/app/theme.dart)):**
   - Modern Dark Theme (deep slate + indigo) and crisp Light Theme with 1-tap toggle in the navigation rail footer.
2. **Collapsible Billing & Quick Dispatch Hub ([`billing_hub_pane.dart`](file:///home/yogesh/workspace/dossier/lib/features/billing_pos/widgets/billing_hub_pane.dart)):**
   - 1-Click collapse button (`chevron_right`) to maximize the center Case Intake workspace; expand icon on the Case banner.
3. **Services Catalog & Fee Breakup Customizer ([`settings_screen.dart`](file:///home/yogesh/workspace/dossier/lib/features/settings/screens/settings_screen.dart) & [`edit_service_dialog.dart`](file:///home/yogesh/workspace/dossier/lib/features/settings/widgets/edit_service_dialog.dart)):**
   - Category Opt-ins (Government Schemes, Printing, Certificates, Utilities, Legal, Financial).
   - Granular fee customizer: Pass-through Portal Fee vs. Kiosk Service Profit.
   - Document requirements checklist manager: Chip tag builder with presets and custom document additions.
4. **Currency & Kiosk Identity Customization:**
   - Multi-currency presets (`₹` INR, `$` USD, `€` EUR, `£` GBP, `AED`, `SAR`, etc.) updating all receipts, POS registers, and case calculations.
   - Custom kiosk name, phone, address, and merchant UPI ID.
