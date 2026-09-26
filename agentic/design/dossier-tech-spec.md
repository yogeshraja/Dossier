# Dossier CRM & Kiosk Vault: Technical Specification

**Version:** 1.0.0  
**Status:** Approved for Implementation  
**Target Ecosystem:** Windows, Android, macOS, iOS, Web (WASM + OPFS)  
**Primary Language / Framework:** Dart / Flutter (v3.24+)  
**Local Persistence:** Drift (SQLite with FFI / WASM)  
**Cloud Infrastructure:** Cloudflare Workers (Edge API), Cloudflare R2 (Managed Vault), Google Drive v3 REST API (Free Tier BYO)

---

## 1. Executive Summary & Architecture Topology

**Dossier** is an offline-first kiosk management system and customer record vault built for Common Service Centres (CSCs), cyber cafes, typing kiosks, and document processing centers. The system operates autonomously on local hardware without requiring continuous internet connectivity, synchronizing state and heavy document artifacts asynchronously.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                               DOSSIER CLIENT ENGINE                                    │
│                                                                                        │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │                        Presentation Layer (Adaptive Flutter)                  │   │
│   │     - Desktop / Tablet Split View (>= 900dp)                                   │   │
│   │     - Mobile Workflow Stepper (< 900dp)                                        │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│   ┌───────────────────────────────────────v────────────────────────────────────────┐   │
│   │                   State & Domain Layer (Riverpod 2.x CodeGen)                  │   │
│   │     - DossierNotifier   - CaseLifecycleNotifier   - MediaPrepNotifier          │   │
│   │     - PosBillingNotifier - SyncCoordinatorNotifier - PeripheralNotifier       │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│   ┌───────────────────────────────────────v────────────────────────────────────────┐   │
│   │                  Specialized Pure-Dart Background Subsystems                   │   │
│   │     - Media Prep Engine (Isolates: Stitcher, Quantizer, 4x6 Grid Tile)         │   │
│   │     - ESC/POS Receipt Builder (58mm / 80mm Raster & Text Stream)               │   │
│   │     - Dynamic UPI QR Formatter (NPCI Standard Payload)                         │   │
│   └───────────────────────────────────────┬────────────────────────────────────────┘   │
│                                           │                                            │
│   ┌───────────────────────────────────────v────────────────────────────────────────┐   │
│   │                     Local Persistence Layer (Drift SQLite)                     │   │
│   │     - Native (Windows/macOS/Android/iOS): SQLite3 via C-FFI                    │   │
│   │     - Web (PWA): SQLite3 WASM + Origin Private File System (OPFS)              │   │
│   │     - Tables: Dossiers, Services, Cases, CaseServices, Exhibits, Invoices,     │   │
│   │               LedgerEntries, SyncQueue                                         │   │
│   └───────────────────┬───────────────────────────────────┬────────────────────────┘   │
│                       │                                   │                            │
└───────────────────────┼───────────────────────────────────┼────────────────────────────┘
                        │                                   │
                        ▼ (Free Tier BYO)                   ▼ (Pro Tier Managed)
     ┌───────────────────────────────────────┐   ┌───────────────────────────────────────┐
     │          Google Drive API v3          │   │       Cloudflare Edge Services        │
     │ - Auth: OAuth2 (drive.file scope)     │   │ - Edge API: Cloudflare Workers (Hono) │
     │ - Uploads: Resumable Chunked Upload   │   │ - Object Storage: Cloudflare R2       │
     │ - Tree: /Dossier_Workspace/...        │   │ - Sync Database: Neon Postgres / D1   │
     │ - Platform Cost: $0.00 / user         │   │ - Presigned S3 Multipart URLs         │
     └───────────────────────────────────────┘   └───────────────────────────────────────┘
```

---

## 2. Client Architecture & State Management

### 2.1 Technology Stack Choices & Dependencies

```yaml
environment:
  sdk: ">=3.4.0 <4.0.0"
  flutter: ">=3.24.0"

dependencies:
  flutter:
    sdk: flutter

  # State Management & DI
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Local Persistence
  drift: ^2.18.0
  drift_flutter: ^0.1.0
  sqlite3: ^2.4.4
  sqlite3_flutter_libs: ^0.5.24

  # Pure-Dart Image & PDF Processing
  image: ^4.2.0
  pdf: ^3.10.8
  printing: ^5.13.0

  # Peripherals & Hardware
  flutter_pos_printer_platform_image_3: ^1.0.8
  qr_flutter: ^4.1.0
  url_launcher: ^6.3.0
  file_picker: ^8.0.5
  camera: ^0.11.0+1

  # Cloud & Networking
  http: ^1.2.1
  google_sign_in: ^6.2.1
  googleapis: ^13.1.0
  uuid: ^4.4.0
  intl: ^0.19.0

dev_dependencies:
  riverpod_generator: ^2.4.0
  drift_dev: ^2.18.0
  build_runner: ^2.4.9
```

### 2.2 Layering & Folder Structure

```
lib/
├── app/
│   ├── app.dart                   # MaterialApp.router, AppThemes, Localization
│   └── router.dart                # GoRouter declarative routing configuration
├── core/
│   ├── constants/                 # UI Dimensions, Color Palettes, Storage Keys
│   ├── errors/                    # AppExceptions, Failure objects
│   ├── extensions/                # Context, DateTime, Currency (INR) extensions
│   └── network/                   # Http client wrapper, connectivity status
├── data/
│   ├── local/
│   │   ├── app_database.dart      # Drift database definition, DAOs, migrations
│   │   ├── connection/            # Conditional imports: native_ffi.dart vs wasm_web.dart
│   │   └── tables/                # Drift table schemas
│   ├── remote/
│   │   ├── gdrive/                # GoogleDriveVaultService implementation
│   │   ├── r2/                    # ManagedR2VaultService implementation
│   │   └── api/                   # Dossier Cloud API client (Auth, Presigned URLs)
│   └── repositories/              # Repository implementations binding DB & Remote
├── domain/
│   ├── models/                    # Freezed immutable domain entities
│   └── repositories/              # Repository abstract interfaces
├── features/
│   ├── dossiers/                  # Customer profiles, search, history
│   ├── cases/                     # Case intake, service selector, stage stepper
│   ├── media_prep/                # ID stitcher, portal compressor, 4x6 photo studio
│   ├── billing_pos/               # Quick walk-in POS, invoices, cash/UPI ledger
│   ├── hardware/                  # Thermal printer discovery, direct Win32/BT spools
│   └── sync/                      # Outbox processor, sync status indicator
└── presentation/
    ├── common_widgets/            # Reusable buttons, dialogs, cards, adaptive panes
    └── theme/                     # High-contrast, modern dark & light themes
```

---

## 3. Local Persistence Layer (Drift SQLite Engine)

### 3.1 Cross-Platform Database Connection

Drift is configured with conditional compilation to support Native desktop/mobile (C-FFI) and Web (WASM + OPFS):

```dart
// lib/data/local/connection/connection.dart
export 'connection_unsupported.dart'
    if (dart.library.ffi) 'connection_native.dart'
    if (dart.library.js_interop) 'connection_web.dart';
```

* **Native (Windows, macOS, Android, iOS):** Uses `sqlite3_flutter_libs` running over `NativeDatabase.createInBackground(dbFile)`. Background isolates are used for non-blocking I/O during heavy search queries.
* **Web (WASM + OPFS):** Uses `WasmDatabase.open()` leveraging `sqlite3.wasm` with `WebStorage.originPrivateFileSystem`. This provides atomic, durable SQLite operations inside the browser without LocalStorage quotas.

### 3.2 Relational Database Schema & Foreign Key Constraints

```sql
-- DDL Equivalent for Drift Schemas

CREATE TABLE dossiers (
    id TEXT PRIMARY KEY NOT NULL,
    full_name TEXT NOT NULL CHECK(length(full_name) BETWEEN 1 AND 120),
    phone_number TEXT NOT NULL CHECK(length(phone_number) BETWEEN 10 AND 15),
    email TEXT,
    notes TEXT,
    remote_folder_id TEXT,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
CREATE INDEX idx_dossiers_phone ON dossiers(phone_number);

CREATE TABLE services (
    id TEXT PRIMARY KEY NOT NULL,
    category TEXT NOT NULL, -- 'GOVT_SCHEME', 'PRINTING', 'CERTIFICATE', 'UTILITY'
    name TEXT NOT NULL CHECK(length(name) BETWEEN 1 AND 150),
    default_portal_fee REAL NOT NULL DEFAULT 0.0,
    default_service_fee REAL NOT NULL DEFAULT 0.0,
    required_docs_json TEXT NOT NULL DEFAULT '[]',
    is_archived INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE cases (
    id TEXT PRIMARY KEY NOT NULL,
    dossier_id TEXT NOT NULL REFERENCES dossiers(id) ON DELETE CASCADE,
    title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 200),
    stage TEXT NOT NULL DEFAULT 'DRAFT', -- 'DRAFT', 'DOCS_PENDING', 'READY_TO_APPLY', 'SUBMITTED', 'READY_FOR_PICKUP', 'CLOSED'
    total_portal_fee REAL NOT NULL DEFAULT 0.0,
    total_service_fee REAL NOT NULL DEFAULT 0.0,
    total_estimated_amount REAL NOT NULL DEFAULT 0.0,
    advance_paid REAL NOT NULL DEFAULT 0.0,
    payment_status TEXT NOT NULL DEFAULT 'UNPAID', -- 'UNPAID', 'PARTIALLY_PAID', 'PAID'
    remote_folder_id TEXT,
    target_date INTEGER,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
CREATE INDEX idx_cases_dossier ON cases(dossier_id);
CREATE INDEX idx_cases_stage ON cases(stage);

CREATE TABLE case_services (
    id TEXT PRIMARY KEY NOT NULL,
    case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    service_id TEXT NOT NULL REFERENCES services(id) ON DELETE RESTRICT,
    applied_portal_fee REAL NOT NULL,
    applied_service_fee REAL NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE exhibits (
    id TEXT PRIMARY KEY NOT NULL,
    case_id TEXT NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
    slot_type TEXT NOT NULL, -- 'AADHAAR_FRONT', 'AADHAAR_BACK', 'PHOTO', 'SIGNATURE', 'ACK_RECEIPT', 'CUSTOM'
    file_name TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    local_path TEXT,
    remote_file_id TEXT,
    file_size_bytes INTEGER NOT NULL,
    is_stitched INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
CREATE INDEX idx_exhibits_case ON exhibits(case_id);

CREATE TABLE invoices (
    id TEXT PRIMARY KEY NOT NULL,
    invoice_number TEXT UNIQUE NOT NULL,
    dossier_id TEXT REFERENCES dossiers(id) ON DELETE SET NULL,
    case_id TEXT REFERENCES cases(id) ON DELETE SET NULL,
    invoice_type TEXT NOT NULL, -- 'WALK_IN_POS', 'CASE_INVOICE'
    subtotal REAL NOT NULL,
    discount REAL NOT NULL DEFAULT 0.0,
    grand_total REAL NOT NULL,
    amount_paid REAL NOT NULL DEFAULT 0.0,
    payment_status TEXT NOT NULL DEFAULT 'UNPAID',
    created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE ledger_entries (
    id TEXT PRIMARY KEY NOT NULL,
    invoice_id TEXT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
    amount REAL NOT NULL,
    payment_mode TEXT NOT NULL, -- 'CASH', 'UPI'
    transaction_ref TEXT,
    recorded_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);

CREATE TABLE sync_queue (
    queue_id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL, -- 'DOSSIER', 'CASE', 'EXHIBIT', 'INVOICE'
    entity_id TEXT NOT NULL,
    operation TEXT NOT NULL, -- 'CREATE', 'UPDATE', 'DELETE'
    payload_json TEXT NOT NULL,
    sync_status TEXT NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'PROCESSING', 'FAILED', 'SUCCESS'
    retry_count INTEGER NOT NULL DEFAULT 0,
    scheduled_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
CREATE INDEX idx_sync_status ON sync_queue(sync_status, scheduled_at);
```

---

## 4. Pluggable Storage Vault Subsystem

### 4.1 Storage Interface Abstraction

```dart
abstract class VaultStorageService {
  Future<String> createCustomerFolder({required String folderName});
  Future<String> createCaseFolder({
    required String parentFolderId,
    required String caseTitle,
  });
  Future<String> uploadExhibit({
    required String parentFolderId,
    required String fileName,
    required String mimeType,
    required Stream<List<int>> dataStream,
    required int length,
    void Function(double progress)? onProgress,
  });
  Future<Uri> getDirectViewUri(String remoteFileId);
  Future<void> deleteExhibit(String remoteFileId);
}
```

### 4.2 Free Tier: BYO Google Drive Implementation

1. **Authentication:**
   * Scopes: `https://www.googleapis.com/auth/drive.file` (access strictly restricted to files and folders created by Dossier).
   * Token refresh and OAuth handling via Google Sign-In with offline refresh token persistence in OS Secure Storage (`flutter_secure_storage`).
2. **Directory Structure in User's Drive:**
   ```
   My Drive/
   └── Dossier_Workspace/
       └── Customers/
           └── {PhoneNumber}_{CustomerName}/
               └── Cases/
                   └── {Date}_{CaseTitle}/
                       ├── metadata.json
                       ├── AADHAAR_STITCHED.pdf
                       └── PASSPORT_PHOTO.jpg
   ```
3. **Resumable Chunked Upload Protocol:**
   * Uses Google Drive API v3 Resumable Upload initiation (`uploadType=resumable`).
   * Splits exhibits into 2 MB chunks for reliable transmission over 2G/3G mobile hotspot connections.

### 4.3 Pro Tier: Managed Cloudflare R2 Vault

1. **Architecture:**
   * Edge Gateway: Cloudflare Worker written in TypeScript / Hono.
   * Object Storage: Cloudflare R2 Bucket (`dossier-vault-production`).
2. **Zero-Egress Direct S3 Presigned Uploads:**
   * Client calls `POST /api/v1/vault/presign-upload` with `{ caseId, fileName, mimeType, sizeBytes }`.
   * Worker verifies active subscription status in database and generates an S3 v4 Presigned `PUT` URL with a 15-minute TTL.
   * Client streams the binary payload directly to Cloudflare R2 via HTTP `PUT`.

```
[Dossier Client] ──1. POST /presign-upload──> [Cloudflare Worker]
       │                                              │ (Verifies JWT + Plan)
       │ <──2. Returns Presigned S3 PUT URL───────────┘
       │
       └──3. Direct HTTP PUT (Stream)───────> [Cloudflare R2 Bucket]
```

---

## 5. Media Prep Studio Implementation

All image processing algorithms are implemented in **pure Dart** and executed in background worker isolates (`compute()` or `Isolate.spawn`) to prevent any UI stutter or frame drops.

### 5.1 ID Card Front/Back Stitcher

* **Input:** Two raw image captures (Front & Back of Aadhaar / Voter ID / Driving License).
* **Processing Pipeline:**
  1. Crop bounding rectangle with optional perspective de-skewing.
  2. Normalize DPI to 300 DPI.
  3. Create an A4 canvas (2480 × 3508 pixels at 300 DPI) or Standard ID Card Canvas (1050 × 600 pixels).
  4. Paste Front on top/left, Back on bottom/right with 40px margin.
  5. Draw a subtle 1px dashed centerline for operator folding/cutting guides.
  6. Output either high-resolution JPEG or single-page PDF.

```
┌──────────────────────────────────────────────┐
│                  A4 Canvas                   │
│  ┌────────────────────────────────────────┐  │
│  │                                        │  │
│  │           ID CARD - FRONT              │  │
│  │                                        │  │
│  └────────────────────────────────────────┘  │
│  - - - - - - - - - - - - - - - - - - - - - - │ (Folding Guide)
│  ┌────────────────────────────────────────┐  │
│  │                                        │  │
│  │           ID CARD - BACK               │  │
│  │                                        │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

### 5.2 Portal Target-Size Compressor (< 200 KB & < 50 KB)

Enforces strict government portal upload constraints (e.g., PAN, SSC, UPSC, state portals) using binary search DCT quantization:

```dart
Future<Uint8List> compressToTargetSize({
  required Uint8List inputBytes,
  required int targetSizeBytes, // e.g. 200 * 1024
  int maxDimension = 1600,
}) async {
  img.Image? decoded = img.decodeImage(inputBytes);
  if (decoded == null) throw Exception("Failed to decode image");

  // Step 1: Downscale dimensions if larger than portal bounds
  if (decoded.width > maxDimension || decoded.height > maxDimension) {
    decoded = img.copyResize(
      decoded,
      width: decoded.width > decoded.height ? maxDimension : -1,
      height: decoded.height >= decoded.width ? maxDimension : -1,
      interpolation: img.Interpolation.cubic,
    );
  }

  // Step 2: Binary Search for optimal JPEG Quality parameter (10 to 95)
  int lowQuality = 10;
  int highQuality = 92;
  Uint8List bestOutput = Uint8List.fromList(img.encodeJpg(decoded, quality: lowQuality));

  while (lowQuality <= highQuality) {
    int mid = (lowQuality + highQuality) ~/ 2;
    Uint8List candidate = Uint8List.fromList(img.encodeJpg(decoded, quality: mid));

    if (candidate.lengthInBytes <= targetSizeBytes) {
      bestOutput = candidate;
      lowQuality = mid + 1; // Try higher quality
    } else {
      highQuality = mid - 1; // Needs more compression
    }
  }

  return bestOutput;
}
```

### 5.3 4×6 Passport Photo Grid Generator

* Standard passport photo aspect ratio: 35mm × 45mm (7:9 ratio).
* Standard lab print sheet: 4 × 6 inches (1200 × 1800 pixels at 300 DPI).
* Generates an exact 6-photo (2×3) or 8-photo (2×4) grid with 2mm white borders and 0.5pt corner cut marks for rapid scissor/guillotine trimming.

---

## 6. Hardware & Communications Integration

### 6.1 ESC/POS Thermal Printing Subsystem

Dossier communicates directly with 58mm (32 characters/line) and 80mm (48 characters/line) thermal printers across three interfaces:

1. **Windows Desktop Direct Spooler (Win32):** Writes raw bytes to printer spool queue (`RawPrinterHelper` via C-FFI / Win32 API).
2. **Android / Mobile Bluetooth (SPP / BLE):** Direct serial stream over RFCOMM socket.
3. **Network / LAN Thermal Printers:** Standard raw TCP socket connection on port `9100`.

#### Thermal Receipt Layout Specification (58mm / 384 dots):
```
================================
         DOSSIER KIOSK          
    Main Market, CSC Centre     
      Phone: +91 98765 43210    
--------------------------------
Invoice: INV-2026-0089          
Date: 26-Sep-2026 02:15 PM      
Customer: Ramesh Kumar          
--------------------------------
Item                Qty   Amount
--------------------------------
Fresh PAN Card        1   200.00
Xerox Copies (B&W)    4    12.00
Lamination            1    20.00
--------------------------------
Subtotal:                ₹232.00
Discount:                  ₹0.00
GRAND TOTAL:             ₹232.00
Advance Paid:            ₹100.00
BALANCE DUE:             ₹132.00
--------------------------------
Scan to Pay Remaining Balance:
         [ QR CODE ]            
UPI ID: csckiosk@oksbi          
--------------------------------
  Thank you for your visit!     
================================
```

### 6.2 Dynamic UPI QR Code Generation

The client generates standard NPCI-compliant payment strings rendered offline via `qr_flutter`:

```
upi://pay?pa={MERCHANT_VPA}&pn={MERCHANT_NAME}&am={REMAINING_BALANCE}&tr={INVOICE_ID}&tn=Dossier_{INVOICE_NO}&cu=INR
```

* **Instant Verification:** Operator can verify payment on their counter smartphone soundbox or bank app; balance updates directly to `ledger_entries`.

### 6.3 Zero-Cost WhatsApp Communication Templates

Uses deep link URIs via `url_launcher` without any third-party gateway subscriptions or Meta API charges:

```dart
class WhatsAppNotifier {
  static Future<void> sendReadyForPickup({
    required String phoneNumber,
    required String customerName,
    required String caseTitle,
    required double balanceDue,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final formattedPhone = cleanPhone.startsWith('91') ? cleanPhone : '91$cleanPhone';

    final message = '''
Namaste $customerName ji,
Your application for *$caseTitle* is complete and ready for pickup at our centre.

Remaining balance to pay: ₹${balanceDue.toStringAsFixed(0)}
Center Location: Main Market Kiosk

Thank you!
''';

    final uri = Uri.parse(
      'whatsapp://send?phone=$formattedPhone&text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback to web WhatsApp URL
      final webUri = Uri.parse(
        'https://wa.me/$formattedPhone?text=${Uri.encodeComponent(message)}',
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}
```

---

## 7. Multi-Counter Sync & Outbox Pattern (Pro Tier)

### 7.1 Sync Engine Operation

Every mutating local transaction (INSERT, UPDATE, DELETE) automatically inserts an event record into `sync_queue` within the same SQLite transaction.

```dart
Future<void> updateCaseStage(String caseId, String newStage) async {
  await db.transaction(() async {
    await (db.update(db.cases)..where((c) => c.id.equals(caseId))).write(
      CasesCompanion(
        stage: Value(newStage),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await db.into(db.syncQueue).insert(
      SyncQueueCompanion.insert(
        entityType: 'CASE',
        entityId: caseId,
        operation: 'UPDATE',
        payloadJson: jsonEncode({'stage': newStage}),
      ),
    );
  });
}
```

### 7.2 Conflict Resolution Strategy

* **Strategy:** Last-Write-Wins (LWW) with client logical timestamps (`updated_at`).
* **Granular Locking:** If two counter operators modify different cases for the same customer, both operations merge cleanly without collisions.
* **Exhibits Immutability:** Exhibit records and file assets are append-only (UUID-keyed), completely eliminating file overwrite conflicts.

---

## 8. Multi-Platform Build & Packaging Pipeline

| Target Platform | Binary Artifact | Build Tooling | Release Verification & Channels |
| :--- | :--- | :--- | :--- |
| **Windows 10/11** | `.msix` & `.exe` (Inno Setup) | `flutter build windows --release` + Inno Setup Script | Code-signed with EV certificate, bundled SQLite3 DLL, direct Win32 Spooler support. |
| **Android** | `.aab` & `.apk` | `flutter build appbundle --release` | Google Play Store, Min SDK 24 (Android 7.0+), Target SDK 34+. |
| **macOS** | `.dmg` & `.pkg` | `flutter build macos --release` | Apple Developer ID signed & Notarized via `altool` / `notarytool`. |
| **iOS / iPadOS** | `.ipa` | `flutter build ipa --release` | Apple App Store & TestFlight distribution. |
| **Web (PWA)** | Static Assets + WASM | `flutter build web --wasm --release` | Cloudflare Pages with required headers: `COOP: same-origin`, `COEP: require-corp`. |

---

## 9. Implementation Roadmap & Milestones

```
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 1: Core Foundation & Storage Bridge                              │
│ ├─ Drift SQLite setup with conditional FFI / WASM loaders              │
│ ├─ Full Database Schema & Repository pattern implementations           │
│ └─ Google Drive OAuth & Cloudflare R2 presigned storage bridges       │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 2: Media Prep Studio & Intake Engine                             │
│ ├─ Pure-Dart ID Front/Back Stitching canvas                           │
│ ├─ Portal DCT Quantization Compressor (<200KB / <50KB)                 │
│ └─ 4x6 Passport Photo Grid generator with cut guidelines              │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 3: Services Catalog, Billing & Hardware Drivers                  │
│ ├─ Master Services configuration with margin calculations             │
│ ├─ ESC/POS 58mm/80mm raw thermal printer driver (USB/Network/BT)       │
│ ├─ Dynamic UPI QR code generator & offline cash ledger                 │
│ └─ WhatsApp intent template launcher                                   │
├────────────────────────────────────────────────────────────────────────┤
│ Phase 4: Platform Packaging, Hardening & Distribution                  │
│ ├─ Windows MSIX / Inno Setup installer automation                      │
│ ├─ Android Play Store bundle & iOS App Store build configurations      │
│ └─ Web PWA WASM / OPFS deployment on Cloudflare Pages                 │
└────────────────────────────────────────────────────────────────────────┘
```
