# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-26  
**Status:** Animated Splash Screen, Micro-Interactions, and Parameterized Component Design System Implemented & Verified

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.
- **Component Design System (`lib/presentation/common_widgets/`):**
  - `DossierButton`: Parametric variants (primary, secondary, outline, danger, success, ghost), sizes (sm, md, lg), press scale micro-animation, hover glow, and loading state.
  - `DossierCard`: Parametric variants (elevated, outlined, glass, flat, gradient), tap scale & hover elevation, custom badges, headers, and footers.
  - `DossierInputField`: Floating labels, clear button, password reveal toggle, search variant, custom borders, and focused glow ring.
  - `DossierPanel`: Expandable/collapsible workstation sections with animated height and rotation transitions.
  - `DossierBadge`: Color-coded semantic tags (primary, success, warning, danger, info, neutral) with optional pulse animation.
  - `DossierDialog`: Reusable modal container with smooth scale-and-fade entry transitions.
- **Splash & Visual Interactions:**
  - `SplashScreen`: Pulsing glowing logo, boot sequence progress tracker, and fade transition into the Kiosk Workstation.
  - `AnimatedSwitcher` page transitions across workstation tabs.

---

## 2. Commit History
- `[Pending Commit]`: `feat(ui): add animated splash screen, interactive micro-animations, and parameterized component library`
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
