# Dossier CRM & Kiosk Vault: Technical Specification

**Version:** 2.0.0  
**Status:** Implemented & Verified (31/31 Tests Passing)  
**Target Ecosystem:** Windows, Android, macOS, iOS, Linux, Web (WASM + OPFS)  
**Primary Language / Framework:** Dart 3.13+ / Flutter 3.47+  
**State Management:** Flutter Riverpod 2.x  
**Local Persistence:** Drift SQLite (C-FFI on Desktop/Mobile, WASM + OPFS on Web)  
**Cloud Storage:** Google Drive REST API v3 (Free Tier BYO), Cloudflare R2 (Pro Managed Tier), Air-Gapped JSON Bundle  
**Hardware Printing:** ESC/POS Raw Binary Driver (58mm / 80mm Thermal Printers)

---

## 1. System Topology & Architecture

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               DOSSIER CLIENT ENGINE                                    │
│                                                                                        │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │                        Presentation Layer (Adaptive Flutter)                  │   │
│   │     - Desktop Multi-Pane (>= 1000dp): Dossiers | Cases & Intake | Billing Hub  │   │
│   │     - Tablet Rail View (640 - 1000dp): Collapsible 2-Pane Workstation          │   │
│   │     - Mobile View (< 640dp): Workflow Stepper with Bottom Navigation           │   │
│   │     - Universal Command Palette (Ctrl+K / Cmd+K): Fuzzy Search & Navigation    │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│   ┌───────────────────────────────────────v────────────────────────────────────────┐   │
│   │                   State & Domain Layer (Riverpod 2.x)                          │   │
│   │     - authProvider (Operator Auth & PIN)   - dossierProviders (Reactive Streams)│   │
│   │     - salesReportProvider (EOD & Audit)    - syncProvider (Outbox Worker)      │   │
│   │     - kioskSettingsProvider (Config & Mode) - isBillingHubExpandedProvider     │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│   ┌───────────────────────────────────────v────────────────────────────────────────┐   │
│   │                  Specialized Pure-Dart Background Subsystems                   │   │
│   │     - Media Prep Engine (Isolates: ID Card Stitcher, DCT Quantizer, 4x6 Grid)  │   │
│   │     - ESC/POS Receipt Driver (58mm/80mm Raw Byte Stream, Cuts, Cash Drawer)    │   │
│   │     - Dynamic UPI QR Formatter (NPCI Payload Standard)                         │   │
│   │     - Backup & Restore Engine (Portable .dossier JSON Bundle Serialization)    │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│   ┌───────────────────────────────────────v────────────────────────────────────────┐   │
│   │                     Local Persistence Layer (Drift SQLite)                     │   │
│   │     - Native Engine (Windows/macOS/Android/iOS/Linux): SQLite3 via C-FFI       │   │
│   │     - Web Engine (PWA): SQLite3 WASM + Origin Private File System (OPFS)       │   │
│   │     - Schema Tables: Dossiers, Services, Cases, CaseServices, Exhibits,        │   │
│   │                      Invoices, LedgerEntries, SyncQueue                        │   │
│   └───────────────────┬───────────────────────────────────┬────────────────────────┘   │
│                       │                                   │                            │
└───────────────────────┼───────────────────────────────────┼────────────────────────────┘
                        │                                   │
                        ▼ (Tier 1: BYO Storage)             ▼ (Tier 2: Managed Vault)
     ┌───────────────────────────────────────┐   ┌───────────────────────────────────────┐
     │          Google Drive API v3          │   │        Managed Cloudflare R2          │
     │ - Auth: OAuth2 (drive.file scope)     │   │ - Edge Storage: Cloudflare R2 (S3 API)│
     │ - Uploads: Resumable Chunk Streaming  │   │ - Zero Egress Cost                    │
     │ - Tree: /Dossier_Workspace/...        │   │ - Presigned S3 Multipart URLs         │
     │ - Direct Drive Web Link Launcher      │   │ - Multi-Counter Live Sync Engine      │
     └───────────────────────────────────────┘   └───────────────────────────────────────┘
```

---

## 2. Riverpod State Providers & Data Contracts

### 2.1 Provider Map (`lib/features/`)
| Provider Name | Type | Scope / Purpose |
| :--- | :--- | :--- |
| `authProvider` | `StateNotifierProvider<AuthNotifier, AuthState>` | Manages active operator, PIN verification, registration, and session switching |
| `databaseProvider` | `Provider<AppDatabase>` | Singleton Drift SQLite database instance |
| `dossiersStreamProvider` | `StreamProvider<List<Dossier>>` | Reactive stream of customer dossiers filtered by `dossierSearchQueryProvider` |
| `activeDossierIdProvider` | `StateProvider<String?>` | Currently selected customer dossier ID |
| `activeDossierProvider` | `Provider<Dossier?>` | Resolved active customer record |
| `activeCasesStreamProvider` | `StreamProvider<List<Case>>` | Reactive stream of cases for the active customer |
| `activeCaseIdProvider` | `StateProvider<String?>` | Currently selected case ID |
| `activeCaseProvider` | `Provider<Case?>` | Resolved active case record |
| `activeCaseExhibitsStreamProvider` | `StreamProvider<List<Exhibit>>` | Attached documents and processed artifacts for the active case |
| `activeServicesStreamProvider` | `StreamProvider<List<Service>>` | Master services and pricing catalog |
| `salesReportProvider` | `StateNotifierProvider<SalesReportNotifier, SalesReportState>` | Selected date range, cash float, and counted drawer cash |
| `salesReportSummaryProvider` | `FutureProvider<SalesReportSummary>` | Aggregated turnover, payment mode splits, service breakdown, and transaction ledger |
| `syncProvider` | `StateNotifierProvider<SyncNotifier, SyncState>` | Outbox queue worker, active upload progress, and audit logs |
| `kioskSettingsProvider` | `StateNotifierProvider<KioskSettingsNotifier, KioskSettings>` | Theme mode, kiosk branding, VPA, and pricing configuration |

---

## 3. Specialized Domain Subsystems & Drivers

### 3.1 Direct ESC/POS Hardware Printing Driver (`EscPosPrinterService`)
Generates raw binary command byte buffers (`Uint8List`) for 58mm and 80mm thermal receipt printers without platform-specific drivers:
- **Command Set:**
  - `ESC @` (`0x1B, 0x40`): Initialize printer hardware.
  - `ESC a n` (`0x1B, 0x61, n`): Text alignment (0=Left, 1=Center, 2=Right).
  - `ESC E n` (`0x1B, 0x45, n`): Text bold toggle.
  - `GS ! n` (`0x1D, 0x21, n`): Double width / height text scaling.
  - `GS V 66 0` (`0x1D, 0x56, 0x42, 0x00`): Partial paper cut.
  - `ESC p 0 25 250` (`0x1B, 0x70, 0x00, 0x19, 0xFA`): 24V cash drawer kick pulse.
- **Methods:**
  - `buildPosReceiptBytes(...)`: Builds formatted customer receipts with store header, two-column dot-leader line items, subtotal/discount/taxes, paid amount, and footer.
  - `buildEodRegisterBytes(...)`: Builds End-of-Day cash drawer audit slips with float reconciliation, gross sales, payment breakdown, and signature lines.

### 3.2 Media Prep Studio Engine (`MediaPrepService`)
Pure-Dart image manipulation executing in Dart background isolates (`compute()`):
- **`stitchIdCards(...)`**: Merges front and back ID scans vertically or horizontally onto a single printable canvas with configurable margins and background fill.
- **`compressToTargetSize(...)`**: Binary search DCT quantization algorithm compressing high-res photos and documents below portal constraints (< 200 KB or < 50 KB).
- **`generatePassportGrid(...)`**: Tiles passport photos onto a 4x6 inch (1200x1800 px @ 300 DPI) sheet with standard cutting guide lines.

### 3.3 Dynamic UPI QR Generator (`UpiQrService`)
Generates standard NPCI-compliant EMVCo UPI payment payloads:
```
upi://pay?pa={merchantVpa}&pn={merchantName}&am={amount}&tn={note}&tr={txnId}&cu=INR
```

### 3.4 Air-Gapped Disaster Recovery Engine (`BackupRestoreService`)
- **`exportBackupBundle(...)`**: Dumps all SQLite tables (Dossiers, Cases, Services, Exhibits, Invoices) into a timestamped `.dossier` JSON snapshot.
- **`restoreBackupBundle(...)`**: Atomic SQLite transaction wiping and reconstructing the relational state from a `.dossier` snapshot.

---

## 4. UI Modernization & Interactive Components

### 4.1 Glassmorphism Design Tokens (`AppThemes`)
- `AppThemes.glassDecoration()` creates multi-layer glassmorphic containers with `glassSurfaceDark` (`0xCC0F172A`) or `glassSurfaceLight` (`0xEEFFFFFF`) and subtle inner bevel highlights (`0x22FFFFFF` / `0x1F0F172A`).
- `DossierCardVariant.glass` utilizes `BackdropFilter(sigmaX: 12, sigmaY: 12)` clipped with `ClipRRect` and `-3px` translateY hover lift physics.
- OpenType `FontFeature.tabularFigures()` applied globally to text themes for aligned financial columns.

### 4.2 Global Command Palette (`CommandPaletteDialog`)
- Accessible via global shortcut `Ctrl + K` / `Cmd + K` or the sidebar quick search bar.
- Keyboard navigation (`↑`, `↓`, `Enter`, `ESC`) with fuzzy query filtering across customer dossiers, cases, quick POS actions, navigation targets, and theme toggles.

### 4.3 Touch POS Quick-Cash Tender Pad (`QuickTenderPad`)
- Touch numpad (`0-9`, `00`, `.`, `C`, `⌫`) with smart denomination chips (`Exact`, `+₹50`, `+₹100`, rounded nearest `₹50`/`₹100`/`₹500`).
- Real-time return change badge (Emerald `Return Change: ₹X.XX` vs. Amber `Shortfall: ₹X.XX`).

### 4.4 Animated Thermal Slip Previewer (`AnimatedThermalReceiptDialog`)
- Custom `_SerratedEdgePainter` rendering realistic zigzag serrated tear cuts.
- Authentic off-white textured thermal receipt styling (`#FAF8F5`) with `Space Mono` typography, dot leaders, simulated barcode strip, and mechanical slide-up paper-feed animation.

### 4.5 Hourly Sales Velocity Sparklines (`SparklineChart`)
- Pure-Dart cubic bezier curve chart with gradient underfill, baseline grid rules, peak detection badges, and hover tooltip scrub line.

---

## 5. Testing & Verification Standard
- **Test Suites:** `test/widget_test.dart` (core workflows) and `test/modernization_test.dart` (UI pillars).
- **Coverage:** 31/31 tests passing with 0 warnings and 0 analyzer issues.
- **Responsive Viewport Validation:** Zero RenderFlex overflows across 320px (mobile), 768px (tablet), 1024px (desktop), and 1440px (ultra-wide kiosk).
