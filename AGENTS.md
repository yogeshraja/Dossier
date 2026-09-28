# AGENTS.md: AI Assistant Ground Rules & Engineering Standards

## 1. Project Identity & Philosophy
- **Product:** Dossier (Offline-First CRM, Kiosk Vault & Touch POS).
- **Domain:** Internet service centers, Common Service Centres (CSCs), cyber cafes, and document processing kiosks.
- **Workspace Monorepo Layout:**
  - `apps/kiosk/`: Cross-platform Flutter client targeting Windows, Android, macOS, iOS, Linux, and Web (WASM).
  - `apps/web/`: Web marketing landing page & interactive documentation portal (Vite + Vanilla CSS/JS).
  - `services/api/`: Cloudflare Workers + D1 SQLite serverless edge backend.

---

## 2. Code Quality & Architectural Standards

### 2.1 State Management & Layer Separation (Riverpod)
- Maintain strict separation of concerns across layers:
  - **UI / Screens / Widgets:** Pure visual presentation and user event dispatching (`apps/kiosk/lib/presentation/` & `apps/kiosk/lib/features/`). Never embed business logic, direct SQLite queries, or disk I/O in Flutter widgets or `build()` methods.
  - **Controllers / Notifiers:** Extend Riverpod `Notifier`, `AsyncNotifier`, or `StateNotifier` to manage business logic and orchestrate domain workflows.
  - **Repositories & DAOs:** Encapsulate all database mutations, outbox queue entries, and remote sync calls.
  - **Domain Services:** Standalone pure-Dart services for media manipulation, ESC/POS hardware formatting, UPI QR generation, WhatsApp intent links, and backup bundle serialization.

### 2.2 Local Persistence & Outbox Sync (Drift SQLite)
- All schema changes must be declared in Drift table files under `apps/kiosk/lib/data/local/tables/`.
- Maintain dual-engine execution:
  - **Desktop / Mobile:** Native C-FFI SQLite driver for maximum speed and raw hardware access.
  - **Web:** SQLite3 compiled to WASM with Origin Private File System (OPFS) and web worker isolation.
- Every mutating local operation on customer records, cases, or exhibits must participate in the `SyncQueue` outbox pattern.

### 2.3 Media Processing & Background Compute
- Heavy image and PDF operations (ID card front/back stitching, DCT quantization portal compression, passport photo tiling, barcode generation) **must execute inside Dart background isolates** (`compute()` or `Isolate.spawn()`) to guarantee 60/120fps UI smoothness.
- Avoid native C++ NDK or platform-specific C-interop dependencies for media manipulation to preserve effortless cross-platform compilation on Windows, Android, macOS, iOS, Linux, and Web.

### 2.4 Hardware Integration (ESC/POS Thermal Printers)
- `EscPosPrinterService` generates raw binary byte command buffers for 58mm and 80mm thermal receipt printers.
- All receipt generation must adhere to standard ESC/POS command sequences:
  - Initialize printer: `ESC @` (`0x1B, 0x40`)
  - Text alignment: `ESC a n` (`0x1B, 0x61, n`)
  - Text bold mode: `ESC E n` (`0x1B, 0x45, n`)
  - Paper cut command: `GS V 66 0` (`0x1D, 0x56, 0x42, 0x00`)
  - Cash drawer kick pulse: `ESC p 0 25 250` (`0x1B, 0x70, 0, 25, 250`)
- Always format receipts with two-column aligned rows matching exact character widths (32 chars for 58mm, 48 chars for 80mm).

### 2.5 Web-First Design & Progressive Local Enhancement Mandate
- **Web-First Philosophy:** Design and build all UI components, user flows, navigation hierarchies, and data interactions for a **modern web experience first**.
  - **Browser Parity:** The app must run smoothly in standard modern web browsers (Chrome, Edge, Firefox, Safari) using Flutter WASM and OPFS.
  - **Fluid Responsive Layouts:** Use CSS-like fluid flex layouts, standard web breakpoints (`320px`, `640px`, `1000px`, `1440px`), smooth hover micro-animations, and full keyboard accessibility (`Tab`, `Escape`, `Enter`, `Ctrl+K` / `Cmd+K`).
  - **Progressive Local Enhancement:** The desktop and mobile native builds take advantage of local OS capabilities (native C-FFI SQLite driver, direct raw ESC/POS thermal printer byte buffers, background Dart isolates for heavy PDF/image compute) as transparent enhancements without fragmenting or diverging from the core web codebase.

### 2.6 Software Activation Gate & Two-Tier Operator Authentication
- **Software Activation Gate:**
  1. The software is initially unactivated/locked. A user must log in or sign up as the **Admin / Owner** to activate the software installation on the device/tenant.
  2. Software activation establishes the master kiosk identity, stores the cloud tenant credentials, and unlocks the application features.
- **Two-Tier Authentication Architecture:**
  1. **Tier 1 (Admin Software Activation):** Master account authentication on remote servers. Manages kiosk settings, cloud backup policies, catalog pricing, and operator provisioning.
  2. **Tier 2 (Daily Desk Operator Shift Login):** Once the software is activated, day-to-day counter staff log in via quick operator selection and 4-digit PIN unlock (or quick credentials).
  3. **Server Synchronization:** All operators created by the Admin are saved to remote servers (Cloudflare D1) and cached locally in Drift SQLite for instant offline operation during network downtime.

### 2.7 UI Modernization & Design Standards
- **Design Tokens & Palette:**
  - Dark Theme: Deep Slate 950 (`#090D16`), Slate 900 (`#0F172A`), Slate 800 (`#1E293B`), Slate 700 (`#334155`).
  - Light Theme: Slate 50 (`#F8FAFC`), Slate 200 (`#E2E8F0`), Pure White (`#FFFFFF`).
  - Accents: Indigo 500 (`#6366F1`), Violet 500 (`#8B5CF6`), Emerald 500 (`#10B981`), Amber 500 (`#F59E0B`), Cyan 500 (`#06B6D4`).
- **Typography:**
  - Google Fonts `Plus Jakarta Sans` for UI elements and headers.
  - Google Fonts `Space Mono` for receipts, financial figures, transaction IDs, and barcode labels.
  - **Mandatory:** Always apply `fontFeatures: [FontFeature.tabularFigures()]` across all text themes to guarantee that all prices, quantities, and timestamps remain monospaced and vertically aligned in tables and cards.
- **Glassmorphism:**
  - Use `AppThemes.glassDecoration()` and `DossierCardVariant.glass` with `BackdropFilter(sigmaX: 12, sigmaY: 12)` and inner border bevels (`0x22FFFFFF` / `0x1F0F172A`).
  - Clip all glassmorphic layers within `ClipRRect(borderRadius: ...)` to prevent blur bleeding onto neighboring widgets.
- **Interactive Micro-Animations:**
  - `DossierButton`: Iridescent rainbow border sweep gradient on hover with `-2px` translateY lift and press micro-scaling. Every button must have a helpful `Tooltip`.
  - `CollapsibleSidebar`: Smooth width transition (240px <-> 76px) with icon tooltips in rail mode.
  - `CommandPaletteDialog`: App-wide `Ctrl + K` / `Cmd + K` modal with keyboard navigation (Up, Down, Enter, Escape) and fuzzy search across dossiers, cases, services, and system tools.
  - `QuickTenderPad`: Touch numpad with smart denomination chips (`Exact`, `+₹50`, `+₹100`) and real-time return change indicator.
  - `AnimatedThermalReceiptDialog`: Custom-painted zigzag serrated tear edge with realistic paper slide-up physics.
  - `SparklineChart`: Pure-Dart cubic bezier curve micro-chart with touch/hover scrub line tooltip.

### 2.8 Zero-Overflow Responsive Layout Mandate
- The UI must adapt seamlessly across all standard breakpoints:
  - **Desktop (≥ 1000dp):** 3-pane split view (Customer Dossiers | Cases & Intake | Billing / Dispatch Hub) or full-width data grids.
  - **Tablet (640dp – 1000dp):** Collapsible 2-pane view with collapsible sidebar rail.
  - **Mobile (< 640dp):** Single-column stepper workflows with bottom navigation bar.
- **Mandatory Layout Rule:** When building button bars, action chips, metric rows, or date selectors, never use unbounded `Row`s that can clip on narrow screens. Always wrap with `Wrap(spacing: ..., runSpacing: ...)` or `LayoutBuilder` / `SingleChildScrollView` to ensure **0 RenderFlex overflows**.

---

## 3. Testing & Verification Standard
- Every feature or component added must be accompanied by unit and widget tests in `test/`.
- All tests must validate:
  1. Component rendering in both Dark and Light themes.
  2. Responsive behavior on narrow mobile viewports (320px) up to ultra-wide desktop viewports (1440px+).
  3. Correct state transitions and provider notifications.
- Before concluding any task, run `flutter analyze` and `flutter test` to ensure:
  - **0 analyzer errors, 0 warnings, 0 unused imports.**
  - **100% test pass rate.**

---

## 4. Communication & Memory Protocol
- Keep `memory.md` updated with the active system state, architectural decisions, completed features, and next steps.
- When finishing a milestone or making foundational design changes, immediately update `memory.md`.
