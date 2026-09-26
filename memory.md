# Project State & Memory: Dossier CRM & Kiosk Vault

**Last Updated:** 2026-09-26  
**Status:** Offline-First Sign-In & Sign-Up Workflow, Multi-Operator Shift Switching, and Quick PIN Unlock Implemented & Verified (21/21 tests passing)

---

## 1. Project Overview & Architecture Decisions
- **Stack:** Flutter 3.47.x (Dart 3.13.x) targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
- **State Management:** Riverpod 2.x with reactive Drift SQLite stream providers.
- **Local DB:** Drift (SQLite) with cross-platform native FFI and WASM + OPFS support.
- **Authentication & Multi-Operator Workflow (`lib/features/auth/`):**
  - `KioskOperator` model: Encapsulates operator profile, assigned role (`admin`, `manager`, `operator`), phone/email identifier, password, 4-digit PIN, and kiosk center details.
  - `authProvider` (`AuthNotifier`): Offline-first authentication controller supporting password sign-in, quick 4-digit PIN unlock, new kiosk registration (onboarding), operator session locking, and fast 1-tap demo logins.
  - `AuthScreen` (`lib/features/auth/screens/auth_screen.dart`): Material Design 3 responsive auth interface with fluid tab transitions between Operator Sign-In and New Kiosk Setup.
    - Two-column showcase layout for desktop/tablet (with branded hero panel and feature highlights) and single-column centered layout for mobile.
    - Interactive 3x4 numeric keypad for 4-digit PIN quick unlocks.
  - Session Integration:
    - `SplashScreen` routes to `AuthScreen` when unauthenticated, and `KioskWorkstationHome` when authenticated.
    - Workstation shell features an Operator avatar pill with quick session management (switch operator shift, lock terminal, log out).
    - Settings screen includes dedicated Operator Profile management.
- **Component Design System (`lib/presentation/common_widgets/`):**
  - `DossierButton`: Parametric variants (primary, secondary, outline, danger, success, warning, ghost), sizes (sm, md, lg), press scale micro-animation, hover glow, and loading state.
  - `DossierCard`: Parametric variants (elevated, outlined, glass, flat, gradient), tap scale & hover elevation, custom badges, headers, and footers.
  - `DossierInputField`: Floating labels, clear button, password reveal toggle, search variant, custom borders, and focused glow ring.
  - `DossierPanel`: Expandable/collapsible workstation sections with animated height and rotation transitions.
  - `DossierBadge`: Color-coded semantic tags with optional pulse animation.
  - `DossierDialog`: Reusable modal container with smooth scale-and-fade entry transitions.
- **Test Suite (`test/widget_test.dart`):**
  - 21 comprehensive test suites verifying Splash boot sequence, multi-resolution responsiveness (Desktop 1440px, Tablet 768px, Mobile 390px, Small Screen 320px), component interactions, and complete Auth flows with zero RenderFlex overflows.

---

## 2. Commit History
- `[HEAD]`: `feat(auth): add offline-first Sign-In, Sign-Up, and Quick 4-Digit PIN unlock workflow with multi-operator switching`
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
