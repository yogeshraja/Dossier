# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-27  
**Status:** Complete 5-Pillar Kiosk UI Modernization Phase Implemented & Verified (31/31 tests passing, 0 analyzer issues)

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers and async sync notifiers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.

### 5-Pillar UI Modernization Suite
1. **Glassmorphic Design System & Ambient Surface Layering (`lib/app/theme.dart`, `lib/presentation/common_widgets/dossier_card.dart`):**
   - `AppThemes.glassDecoration()` with `glassSurfaceDark` (`0xCC0F172A`) and `glassSurfaceLight` (`0xEEFFFFFF`).
   - `DossierCardVariant.glass` utilizing inner `BackdropFilter(sigmaX: 12, sigmaY: 12)` with subtle inner bevel highlight (`0x22FFFFFF` / `0x1F0F172A`).
   - OpenType `FontFeature.tabularFigures()` applied across all text themes to keep financial figures, receipts, and timestamps monospaced and vertically aligned.
   - Smooth `-3px` translateY hover lift physics and ambient colored shadow bloom.

2. **Global Command Palette & Universal Quick Search (`lib/presentation/widgets/command_palette_dialog.dart`):**
   - `Ctrl + K` / `Cmd + K` global keyboard shortcut with `CallbackShortcuts` and sidebar search trigger.
   - Fast fuzzy search and keyboard navigation (Up, Down, Enter, Escape) across customer dossiers, active cases, POS services, navigation routes, and system actions.
   - Visual category badges (`[Customer Dossiers]`, `[Active Cases]`, `[Quick POS]`, `[Navigation]`, `[System]`).

3. **Touch POS Quick-Cash Tender Pad & Change Calculator (`lib/features/billing_pos/widgets/quick_tender_pad.dart`):**
   - Instant touch numpad (`0-9`, `00`, `.`, `C`, `⌫`) for cash transactions at kiosk counters.
   - Smart currency denomination chips (`Exact`, `+₹50`, `+₹100`, nearest rounded ₹50/₹100/₹500 bills).
   - Real-time return change status pill (Emerald `Return Customer Change: ₹X.XX` vs Amber `Shortfall Due: ₹X.XX`).
   - Integrated into `QuickPosScreen` and `RecordPaymentDialog`.

4. **Animated Thermal Slip Paper-Feed Previewer (`lib/presentation/widgets/animated_thermal_receipt.dart`):**
   - Custom `CustomPainter` `_SerratedEdgePainter` rendering realistic zigzag serrated tear edges.
   - Authentic ivory thermal receipt styling (`#FAF8F5`) with monospace thermal typography (`Space Mono`).
   - Dot leaders, itemized line tables, barcode simulation, and slide-up printer paper-feed animation.
   - 1-Click ESC/POS raw hardware printer dispatch (`EscPosPrinterService.buildPosReceiptBytes`) and clipboard text copy.
   - Integrated into `BillingHubPane`, `QuickPosScreen`, and `DailySalesRegisterScreen`.

5. **Interactive Sparkline Micro-Chart (`lib/presentation/widgets/sparkline_chart.dart`):**
   - Pure Dart cubic bezier curve graph with smooth gradient fill under the curve.
   - Interactive touch/hover scrub line with tooltip popover displaying exact hour, revenue, and transaction volume.
   - Peak value detection badge and baseline grid lines.
   - Integrated into `DailySalesRegisterScreen` for live hourly sales velocity analysis.

---

## 2. Testing & Quality Assurance
- **Total Tests:** 31/31 unit, integration, and widget tests passing (100% pass rate).
- **Analyzer Status:** 0 errors, 0 warnings, 0 lints.
- **Responsiveness:** Validated on viewport widths from 320px mobile up to 1440px multi-pane desktop workstation with 0 RenderFlex overflows.

---

## 3. Commit History
- `[HEAD]`: `feat(modernization): implement 5-pillar UI overhaul with glassmorphism, Ctrl+K command palette, quick cash tender pad, animated thermal receipts, and sparkline charts`
- `[PREV]`: `feat(printing): add ESC/POS raw hardware byte driver, Daily Sales register, and Cloudflare R2 backup vault`
- `[PREV]`: `feat(ui): add rainbow hover border sweep to buttons, collapsible animated sidebar, and Google Fonts typography`
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
