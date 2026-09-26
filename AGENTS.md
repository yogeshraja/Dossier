# AGENTS.md: AI Assistant Ground Rules & Engineering Standards

## 1. Project Identity & Philosophy
- **Product:** Dossier (Offline-First CRM & Kiosk Vault).
- **Domain:** Cyber cafes, CSC (Common Service Centres), and document processing kiosks.
- **Core Architecture:** Offline-first, reactive (Riverpod), local SQL (Drift SQLite), pure Dart image manipulation, pluggable cloud vault (BYO Google Drive vs Managed Cloudflare R2).

---

## 2. Code Quality & Architectural Rules

### 2.1 State Management & Architecture
- Use **Riverpod** for state management. Separate UI, Notifiers/Controllers, Repositories, DAOs, and Domain Services cleanly.
- Never place business logic, heavy calculations, or DB/disk I/O inside Flutter widgets or `build()` methods.

### 2.2 Local Persistence (Drift SQLite)
- All schema changes must be declared in Drift table files under `lib/data/local/tables/`.
- Ensure dual-engine support: Native C-FFI for Desktop/Mobile and WASM + OPFS for Web.
- Every mutating local operation must participate in the `SyncQueue` outbox pattern.

### 2.3 Media & Background Compute
- Heavy image and PDF operations (ID card stitching, DCT quantization compression, passport photo tiling) **must run in Dart background isolates** (`compute()` or `Isolate.spawn`) to ensure 60/120fps UI smoothness.
- Avoid native C++ NDK/C-interop dependencies for media unless strictly required, to preserve effortless cross-platform compilation on Windows, Android, macOS, iOS, and Web.

### 2.4 UI & Design System
- Deliver a premium, high-density kiosk workstation experience.
- Maintain responsive adaptive layouts:
  - **Desktop / Large Screen (≥ 900dp):** 3-pane split view (Dossiers List | Cases & Intake | Document / Billing Hub).
  - **Mobile / Small Screen (< 900dp):** Workflow stepper with bottom navigation.
- High-contrast typography and clear visual cues for fast counter operations.

---

## 3. Communication & Memory Protocol
- Keep `memory.md` updated with the current system state, architectural decisions, completed features, and active blockers.
- When finishing a milestone or making foundational design changes, immediately record the update in `memory.md`.
