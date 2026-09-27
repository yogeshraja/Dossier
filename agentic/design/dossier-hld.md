# Master High-Level Design (HLD): Dossier CRM & Kiosk Vault

## 1. System Vision & Business Architecture

**Dossier** is an offline-first, multi-platform customer relationship manager (CRM), point-of-sale (POS), document intake studio, and secure storage vault designed specifically for internet service centers, cyber cafes, Common Service Centres (CSCs), and document processing kiosks.

### Core Value Proposition & Monetization Model
* **Free / BYO Storage Tier (Zero Infrastructure Cost):** Operators use **"Bring Your Own Storage" (BYO Google Drive)**. Heavy artifacts (scans, receipts, application PDFs) sync directly to the operator's Google Drive account (`drive.file` scope) with automatic folder structuring (`/Dossier_Workspace/<Customer_Phone_Name>/<Case_ID_Title>/<Exhibits>`). Gross margin to platform: **100%**.
* **Dossier Pro Managed Tier (₹249 – ₹299/mo):** Operators access a **Managed Cloud Vault (Cloudflare R2 / AWS S3)** with presigned chunk uploads, zero egress fees, multi-counter real-time sync across 2–4 counter PCs, automated portal compression (< 200 KB), and air-gapped disaster recovery snapshot exports.
* **Air-Gapped Local Tier:** Complete local-only operation with Drift SQLite relational persistence and `.dossier` encrypted JSON bundle export/import for fully offline government/rural kiosks.

### Target Platforms
* **Desktop:** Windows (MS Store `.msix` & Inno Setup `.exe`), macOS (Notarized `.dmg`), Linux (`.tar.gz` / AppImage)
* **Mobile & Tablets:** Android (Play Store `.aab`), iOS (App Store `.ipa`)
* **Web:** Progressive Web App (PWA) compiled to WebAssembly (WASM + OPFS)

---

## 2. End-to-End System Architecture

```
+-----------------------------------------------------------------------------------------+
|                                DOSSIER CLIENT APPLICATION                               |
|                  (Flutter: Windows / Android / macOS / iOS / Linux / Web-PWA)           |
|                                                                                         |
|  +-----------------------------------------------------------------------------------+  |
|  |                            Presentation Layer & Shell                             |  |
|  |   - Mobile (<640px): Workflow Stepper / Touch Numpad / Bottom Navigation          |  |
|  |   - Tablet (640-1000px): Collapsible 2-Pane View / Rail Navigation                |  |
|  |   - Desktop (>=1000px): Adaptive 3-Pane Workstation (Dossiers | Cases | Hub)      |  |
|  |   - Global Command Palette (Ctrl+K / Cmd+K) Universal Fuzzy Search                |  |
|  +-----------------------------------------+-----------------------------------------+  |
|                                            |                                            |
|  +-----------------------------------------v-----------------------------------------+  |
|  |                    Specialized Subsystems & Domain Engines                        |  |
|  |  +----------------------+ +-----------------------+ +--------------------------+  |  |
|  |  | Media Prep Studio    | | POS & Billing Register| | Hardware & Comms Driver  |  |  |
|  |  | - ID Card Stitcher   | | - Touch Tender Pad    | | - ESC/POS Raw Byte Gen   |  |  |
|  |  | - Portal Compressor  | | - Change Calculator   | | - 58mm/80mm Thermal Slips|  |  |
|  |  | - Passport Grid 4x6  | | - Daily Sales Audit   | | - Dynamic UPI QR (EMV)   |  |  |
|  |  | - Pure-Dart Isolates | | - Hourly Sparklines   | | - WhatsApp Intent Alerts |  |  |
|  |  +----------+-----------+ +-----------+-----------+ +------------+-------------+  |  |
|  |             |                         |                          |                |  |
|  |  +----------v-----------+ +-----------v-----------+ +------------v-------------+  |  |
|  |  | Auth & Operator      | | Disaster Recovery     | | Services Catalog         |  |  |
|  |  | - 4-Digit PIN Lock   | | - .dossier Snapshot   | | - Gov Scheme Portal Fees |  |  |
|  |  | - Role Capabilities  | | - 1-Click Restore     | | - Profit Margin Split    |  |  |
|  |  +----------------------+ +-----------------------+ +--------------------------+  |  |
|  +-----------------------------------------+-----------------------------------------+  |
|                                            |                                            |
|  +-----------------------------------------v-----------------------------------------+  |
|  |                         State Management (Riverpod 2.x)                           |  |
|  |    AuthState | DossiersStream | ActiveCasesStream | SalesReport | SyncNotifier    |  |
|  +-----------------------------------------+-----------------------------------------+  |
|                                            |                                            |
|  +-----------------------------------------v-----------------------------------------+  |
|  |                 Pluggable Storage Bridge & Sync Coordinator                       |  |
|  |                   (Outbox Pattern with Drift SQLite SyncQueue)                    |  |
|  +----------------------+------------------------------------+---------------------+  |
|                         |                                    |                        |
|  +----------------------v--------------+       +-------------v---------------------+  |
|  |  Local Storage Engine (Drift SQLite)|       | Pluggable Cloud Vault Connector   |  |
|  |  - FFI Engine (Desktop/Mobile)      |       | (Swappable Storage Strategy)      |  |
|  |  - WASM + OPFS (Web PWA)            |       +-------+-------------------+-------+  |
|  |  - Dossiers       - Services        |               |                   |          |
|  |  - Cases          - Invoices        |               |                   |          |
|  |  - Exhibits       - SyncQueue       |               |                   |          |
|  +-------------------------------------+               |                   |          |
+--------------------------------------------------------|-------------------|----------+
                                                         |                   |
                               +-------------------------+                   |
                               |                                             |
                               v                                             v
+----------------------------------------------------+   +------------------------------+
|            TIER 1: BYO GOOGLE DRIVE                |   |    TIER 2: MANAGED CLOUDFLARE|
|  - Google Drive REST API v3 (`drive.file` scope)   |   |            R2 CLOUD VAULT    |
|  - Root: /Dossier_Workspace                        |   |  - Zero Egress Cost (S3 API) |
|    └── {Customer_Phone_Name}                       |   |  - Presigned Chunk Streaming |
|        └── {Case_ID_Title}                         |   |  - Multi-Counter Multi-PC    |
|            ├── meta.json                           |   |    Concurrent Sync           |
|            └── Exhibits (PDF/JPG)                  |   +------------------------------+
+----------------------------------------------------+
```

---

## 3. Core Subsystems & Domain Modules

### 3.1 Direct ESC/POS Hardware Printing & Peripheral Driver
- **`EscPosPrinterService` (`lib/domain/services/esc_pos_printer_service.dart`)**:
  - Generates standard ESC/POS binary byte buffers across 58mm (32 chars/line) and 80mm (48 chars/line) thermal paper formats.
  - Implements hardware cut commands (`GS V 66 0`), cash drawer kick pulses (`ESC p 0 25 250`), dynamic text scaling, bold styling, and two-column dot-leader alignments.
  - Generates Walk-in POS slips, Case Invoices, and End-of-Day (EOD) Register Closure reports.

### 3.2 Daily Sales & Cash Reconciliation Register
- **`DailySalesRegisterScreen` (`lib/features/billing_pos/screens/daily_sales_register_screen.dart`)**:
  - Aggregates live invoice transactions across flexible date ranges (`TODAY`, `YESTERDAY`, `THIS_WEEK`, `THIS_MONTH`).
  - Cash drawer audit tracking opening float, cash inflow, and counted physical cash with automated variance badges (`BALANCED`, `OVERAGE`, `SHORTAGE`).
  - Pure-Dart **`SparklineChart`** rendering real-time cubic bezier hourly traffic curves with hover tooltip scrubbing.

### 3.3 Touch POS Quick-Cash Tender Pad
- **`QuickTenderPad` (`lib/features/billing_pos/widgets/quick_tender_pad.dart`)**:
  - High-density 10-key touch PIN pad (`0-9`, `00`, `.`, `C`, `⌫`) for rapid counter transactions.
  - Smart denomination chips (`Exact`, `+₹50`, `+₹100`, rounded nearest ₹50/₹100/₹500 bills).
  - Real-time return change calculation and shortfall alert badges.

### 3.4 Multi-Operator Authentication & Role Control
- **`AuthNotifier` (`lib/features/auth/providers/auth_provider.dart`)**:
  - 100% offline-first operator management with bcrypt-style secure password and 4-digit PIN storage.
  - Role capabilities distinguishing `Owner / Manager` (administrative pricing, EOD closure, backup exports) and `Operator` (counter sales, case intake, media processing).
  - Rapid operator switching directly accessible via the top bar and sidebar profile card.

### 3.5 Global Command Palette & Quick Search
- **`CommandPaletteDialog` (`lib/presentation/widgets/command_palette_dialog.dart`)**:
  - App-wide keyboard shortcut (`Ctrl + K` / `Cmd + K`) for instant keyboard-driven counter operations.
  - Fuzzy indexing across customer records, active cases, POS services, navigation targets, and theme modes.
  - Up/Down arrow selection, Enter to execute, and Escape to dismiss.

### 3.6 Media Prep Studio (Pure-Dart Background Isolates)
- **`MediaPrepService` (`lib/domain/services/media_prep_service.dart`)**:
  - ID Card Stitcher: Merges front and back scans vertically or horizontally with customizable border padding and background canvas.
  - Portal Compressor: Dynamic DCT quantization binary search compressing heavy PDFs and images below portal size limits (e.g. < 200 KB or < 50 KB).
  - Passport Photo Grid: Pure-Dart 4x6 inch / A4 photo sheet generator with 8, 16, or 32 grid layouts for thermal/inkjet photo printers.

### 3.7 Pluggable Cloud Vault & Air-Gapped Disaster Recovery
- **`GoogleDriveVaultService`**: BYO Google Drive OAuth2 integration with automatic workspace hierarchy creation and file streaming.
- **`ManagedR2VaultService`**: Presigned S3 chunk streaming to Cloudflare R2 with zero egress fees.
- **`BackupRestoreService`**: Portable `.dossier` JSON bundle serialization and full SQLite transaction restore for air-gapped rural centers.

---

## 4. Complete Database Schema (Drift SQLite)

```dart
// Schema Tables declared in lib/data/local/tables/schema.dart:
// 1. Dossiers (Customers/Clients)
// 2. Cases (Jobs & Applications)
// 3. Services (Service Catalog & Portal Fees)
// 4. CaseServices (Case Line Items)
// 5. Exhibits (Attached Documents, Scans & Output Artifacts)
// 6. Invoices (POS & Case Billing Records)
// 7. LedgerEntries (Financial Double-Entry Audit Trail)
// 8. SyncQueue (Outbox Mutation Pattern)
```

---

## 5. UI/UX Design System Standards
- **Typography:** Google Fonts `Plus Jakarta Sans` for UI, `Space Mono` for receipts and tabular numbers.
- **OpenType Tabular Figures:** Mandatory `FontFeature.tabularFigures()` applied globally to align financial columns.
- **Glassmorphism:** `AppThemes.glassDecoration()` and `DossierCardVariant.glass` with `BackdropFilter` and inner bevel borders.
- **Micro-Animations:** Iridescent rainbow hover border sweeps, smooth collapsible sidebar (240px <-> 76px), and paper-feed receipt rollouts.
- **Responsiveness:** Strict 0-RenderFlex-overflow mandate supporting 320px mobile viewports up to 1440px+ multi-pane workstations.