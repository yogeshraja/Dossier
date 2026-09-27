# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-27  
**Status:** Advanced UI Modernization & Kiosk Diagnostics Suite Implemented & Verified (35/35 tests passing, 0 analyzer issues)

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers and async sync notifiers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.

### Complete UI Modernization Suite
1. **Interactive Case Stage Progression Timeline (`lib/presentation/widgets/case_stage_timeline.dart`):**
   - 6 milestone stages: `Intake` ➔ `Docs Needed` ➔ `Ready to Apply` ➔ `Submitted` ➔ `Ready for Pickup` ➔ `Completed`.
   - Glowing active step node, completed emerald checks, and live document checklist completion counter (`Docs: X/Y (Z%)`).
   - Integrated into `CaseIntakePane` with 1-click stage advancement.

2. **Ambient Hardware & Cloud Vault Status Bar (`lib/presentation/widgets/kiosk_status_bar.dart`):**
   - Ambient status pill embedded in desktop top workspace header and mobile AppBar.
   - Live indicators for Cloud Vault engine (Google Drive / Cloudflare R2 / Air-Gapped), pending sync outbox count, and ESC/POS thermal printer ready driver.
   - Interactive popover modal for hardware diagnostics and 1-click sync dispatch.

3. **Smart Dossier Directory Filters & Urgency Badges (`lib/features/dossiers/widgets/dossier_list_pane.dart`):**
   - Segmented filter chips: `All`, `Active Jobs`, `Pending Docs`, and `Unpaid Dues`.
   - Urgency avatar rings: Amber for pending customer documents, Emerald for ready for pickup, and Rose pill for outstanding dues balance.

4. **Floating Glassmorphic Action Toast & Notification System (`lib/presentation/widgets/dossier_toast.dart`):**
   - Backdrop blur (`sigmaX: 14, sigmaY: 14`), colored border bevels, status icons, and live countdown timer progress bar.
   - Action callback triggers (e.g. `[View Receipt]`, `[WhatsApp]`, `[Undo]`) and swipe-to-dismiss gesture support.

5. **Visual Media Compression Gauge & Studio Ruler (`lib/features/media_prep/screens/media_prep_studio_screen.dart`):**
   - Dual-canvas preview with compression savings progress bar and quality preset chips (Portal 50KB / 100KB / 200KB / Uncompressed).

6. **Glassmorphic Design System & Ambient Surface Layering (`lib/app/theme.dart`, `lib/presentation/common_widgets/dossier_card.dart`):**
   - `AppThemes.glassDecoration()` with `glassSurfaceDark` (`0xCC0F172A`) and `glassSurfaceLight` (`0xEEFFFFFF`).
   - `DossierCardVariant.glass` utilizing inner `BackdropFilter(sigmaX: 12, sigmaY: 12)` with subtle inner bevel highlight (`0x22FFFFFF` / `0x1F0F172A`).
   - OpenType `FontFeature.tabularFigures()` (`AppThemes.tabularFigures`) applied across all numeric tables, cards, and receipts.

7. **Global Command Palette (`lib/presentation/widgets/command_palette_dialog.dart`):**
   - `Ctrl + K` / `Cmd + K` modal with fuzzy search across customer dossiers, cases, services, and system tools.

8. **Touch POS Quick-Cash Tender Pad (`lib/features/billing_pos/widgets/quick_tender_pad.dart`):**
   - Touch numpad with smart denomination chips (`Exact`, `+₹50`, `+₹100`) and real-time return change indicator.

9. **Animated Thermal Slip Paper-Feed Previewer (`lib/presentation/widgets/animated_thermal_receipt.dart`):**
   - Custom-painted zigzag serrated tear edge with realistic paper slide-up physics, monospace receipt formatting, and ESC/POS direct printing.

10. **Interactive Sparkline Micro-Chart (`lib/presentation/widgets/sparkline_chart.dart`):**
    - Pure Dart cubic bezier curve graph with touch/hover scrub line tooltip for hourly register flow.

---

## 2. Testing & Quality Assurance
- **Total Tests:** 35/35 unit, integration, and widget tests passing (100% pass rate).
- **Analyzer Status:** 0 errors, 0 warnings, 0 lints.
- **Responsiveness:** Validated on viewport widths from 320px mobile up to 1440px multi-pane desktop workstation with 0 RenderFlex overflows.

---

## 3. Commit History
- `[HEAD]`: `fix(linux): suppress Mesa/EGL virtual DRI fallback logs and configure default Adwaita GTK cursor theme`
- `[PREV]`: `feat(modernization): add CaseStageTimeline, ambient KioskStatusBar, smart Dossier filters, and floating DossierToast notifications`
- `[PREV]`: `feat(modernization): implement 5-pillar UI overhaul with glassmorphism, Ctrl+K command palette, quick cash tender pad, animated thermal receipts, and sparkline charts`
- `[PREV]`: `feat(printing): add ESC/POS raw hardware byte driver, Daily Sales register, and Cloudflare R2 backup vault`
- `[PREV]`: `feat(ui): add rainbow hover border sweep to buttons, collapsible animated sidebar, and Google Fonts typography`
- `[PREV]`: `feat(ux): overhaul UI consistency, dynamic POS catalog, case notes, and direct payment workflows`
- `[PREV]`: `feat(attachments): implement real file picking, document preview, exhibit deletion, and zero-dummy-data clean state`
- `[PREV]`: `feat(auth): add offline-first Sign-In, Sign-Up, and Quick 4-Digit PIN unlock workflow with multi-operator switching`
