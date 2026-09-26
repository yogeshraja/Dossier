```markdown
# Master High-Level Design (HLD): Dossier CRM & Kiosk Vault

## 1. System Vision & Business Architecture

**Dossier** is an offline-first, multi-platform customer record manager, point-of-sale (POS), and document processing vault tailored for internet service centers, cyber cafes, CSCs (Common Service Centres), and document typing kiosks.

### Core Value Proposition & Monetization Model
* **Free Tier (Zero Infrastructure Cost):** Operators use **"Bring Your Own Storage" (BYO Google Drive)**. All heavy artifacts (scans, receipts, PDFs) sync to the operator’s personal Google Drive (`drive.file` scope). Gross margin to the platform: **100%**.
* **Dossier Pro Tier (₹249 – ₹299/mo):** Operators get a **Managed Cloud Vault (Cloudflare R2 / AWS S3)** with instant 1-click cloud sync (no Google account setup required), multi-device real-time sync across 2–4 counter PCs, automated portal compression (< 200 KB), ID front/back auto-stitching, and ESC/POS thermal printing. Infrastructure cost: ~$0.20 to $0.35 per user per month (> 90% net margin).

### Target Platforms
* **Mobile:** Android (Play Store `.aab`), iOS (App Store `.ipa`)
* **Desktop:** Windows (MS Store `.msix` & Inno Setup `.exe`), macOS (Notarized `.dmg` / App Store `.pkg`)
* **Web:** Progressive Web App (PWA) compiled to WebAssembly (WASM + OPFS)

---

## 2. End-to-End System Architecture

+-------------------------------------------------------------------------------+
|                            DOSSIER CLIENT APPLICATION                         |
|                 (Flutter: Android / iOS / Windows / macOS / Web-PWA)          |
|                                                                               |
|  +-------------------------------------------------------------------------+  |
|  |                          Presentation Layer                             |  |
|  |   - Mobile (<900px): Bottom Bar / Camera Scanner / Stage Stepper Chips  |  |
|  |   - Desktop/PWA (>=900px): 3-Pane Adaptive Split (Dossiers|Cases|Hub)   |  |
|  +-------------------------------------+-----------------------------------+  |
|                                        |                                      |
|  +-------------------------------------v-----------------------------------+  |
|  |                   Specialized Subsystems & Engines                      |  |
|  |  +---------------------+ +----------------------+ +------------------+  |  |
|  |  | Media Prep Engine   | | Services & Estimate  | | Billing & Comms  |  |  |
|  |  | - ID Merger (F/B)   | | - Services Catalog   | | - Dynamic UPI QR |  |  |
|  |  | - Portal Compressor | | - Auto-Doc Checklist | | - WhatsApp Intent|  |  |
|  |  | - 4x6 Photo Grid    | | - Margin Breakdown   | | - ESC/POS Thermal|  |  |
|  |  +----------+----------+ +----------+-----------+ +--------+---------+  |  |
|  +-------------|-----------------------|----------------------|------------+  |
|                +-----------------------+----------------------+               |
|                                        |                                      |
|  +-------------------------------------v-----------------------------------+  |
|  |                     State Management (Riverpod)                         |  |
|  |       DossierState | CaseState | ServiceState | BillingState            |  |
|  +-------------------------------------+-----------------------------------+  |
|                                        |                                      |
|  +-------------------------------------v-----------------------------------+  |
|  |               Pluggable Storage Bridge & Sync Coordinator               |  |
|  |                 (Outbox Pattern with SyncQueue Table)                   |  |
|  +-------------------+---------------------------------+-------------------+  |
|                      |                                 |                      |
|  +-------------------v----------+       +--------------v-------------------+  |
|  |  Local Storage Engine (Drift)|       | Storage Vault Connector          |  |
|  |  (FFI: Native | WASM: Web)   |       | (Swappable Strategy Pattern)     |  |
|  |  - Dossiers     - Services   |       +-------+------------------+-------+  |
|  |  - Cases        - Invoices   |               |                  |          |
|  |  - Exhibits     - SyncQueue  |               |                  |          |
|  +------------------------------+               |                  |          |
+-------------------------------------------------|------------------|----------+
                                                  |                  |
                         +------------------------+                  |
                         |                                           |
                         v                                           v
+--------------------------------------------------+   +------------------------+
|             FREE TIER: BYO GOOGLE DRIVE          |   |   PRO TIER: MANAGED    |
| - Google Drive API v3 (Scope: drive.file)        |   |   CLOUD VAULT (S3/R2)  |
| - Root: /Dossier_Workspace                       |   | - Cloudflare R2 / S3   |
|   └── Customers/{Phone}_{Name}                   |   | - Zero Google OAuth    |
|       └── Cases/{Date}_{Title}                   |   | - Signed Presigned URLs|
|           ├── meta.json                          |   | - Multi-Counter Live   |
|           └── Exhibits (PDF/JPG)                 |   |   Concurrency          |
+--------------------------------------------------+   +------------------------+

---

## 3. Storage Strategy: Pluggable Vault Connector

The client abstracts file synchronization behind a unified `VaultStorageService` interface. The implementation switches based on the operator's subscription tier:

```dart
abstract class VaultStorageService {
  Future<String> createCustomerFolder(String folderName);
  Future<String> createCaseFolder(String parentFolderId, String caseTitle);
  Future<String> uploadExhibit({
    required String parentFolderId,
    required String fileName,
    required String mimeType,
    required Stream<List<int>> dataStream,
    required int length,
  });
  Future<Uri> getDirectViewUri(String remoteFileId);
}

```

* **`GoogleDriveVaultService` (Free Tier):** Executes direct Google Drive v3 REST calls using the user’s authenticated OAuth token. Runs chunked resumable uploads directly to the user's `ServiceCenter_CRM` folder tree.
* **`ManagedR2VaultService` (Pro Tier):** Obtains short-lived presigned upload URLs from the Dossier backend API and streams files straight to Cloudflare R2 ($0 egress fees, multi-counter write locking).

---

## 4. Complete Relational Database Schema (Drift SQLite)

```dart
import 'package:drift/drift.dart';

// --- CUSTOMERS / PROFILES ---
class Dossiers extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get fullName => text().withLength(min: 1, max: 120)();
  TextColumn get phoneNumber => text().withLength(min: 10, max: 15)();
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get remoteFolderId => text().nullable()(); // Drive folder ID or R2 bucket prefix
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- SERVICES MASTER CATALOG ---
class Services extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get category => text()(); // GOVT_SCHEME, PRINTING, CERTIFICATE, UTILITY
  TextColumn get name => text().withLength(min: 1, max: 150)();
  RealColumn get defaultPortalFee => real().withDefault(const Constant(0.0))(); // Pass-through cost
  RealColumn get defaultServiceFee => real().withDefault(const Constant(0.0))(); // Kiosk profit
  TextColumn get requiredDocsJson => text().withDefault(const Constant('[]'))(); // ['AADHAAR', 'PHOTO']
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- JOBS / CASES ---
class Cases extends Table {
  TextColumn get id => text()(); // UUID v4
  TextColumn get dossierId => text().references(Dossiers, #id)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get stage => text()(); // DRAFT, DOCS_PENDING, READY_TO_APPLY, SUBMITTED, READY_FOR_PICKUP, CLOSED
  RealColumn get totalPortalFee => real().withDefault(const Constant(0.0))();
  RealColumn get totalServiceFee => real().withDefault(const Constant(0.0))();
  RealColumn get totalEstimatedAmount => real().withDefault(const Constant(0.0))();
  RealColumn get advancePaid => real().withDefault(const Constant(0.0))();
  TextColumn get paymentStatus => text()(); // UNPAID, PARTIALLY_PAID, PAID
  TextColumn get remoteFolderId => text().nullable()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- CASE SERVICES (LINE ITEMS PER CASE) ---
class CaseServices extends Table {
  TextColumn get id => text()();
  TextColumn get caseId => text().references(Cases, #id)();
  TextColumn get serviceId => text().references(Services, #id)();
  RealColumn get appliedPortalFee => real()();
  RealColumn get appliedServiceFee => real()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

// --- ARTIFACTS / EXHIBITS ---
class Exhibits extends Table {
  TextColumn get id => text()();
  TextColumn get caseId => text().references(Cases, #id)();
  TextColumn get slotType => text()(); // AADHAAR_FRONT, PHOTO, SIGNATURE, ACK_RECEIPT, CUSTOM
  TextColumn get fileName => text()();
  TextColumn get mimeType => text()();
  TextColumn get localPath => text().nullable()(); // Nullable on web PWA
  TextColumn get remoteFileId => text().nullable()();
  IntColumn get fileSizeBytes => integer()();
  BoolColumn get isStitched => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- BILLING: INVOICES & QUICK POS ---
class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceNumber => text().unique()(); // e.g., INV-2026-0042
  TextColumn get dossierId => text().nullable().references(Dossiers, #id)();
  TextColumn get caseId => text().nullable().references(Cases, #id)();
  TextColumn get invoiceType => text()(); // WALK_IN_POS, CASE_INVOICE
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real()();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  TextColumn get paymentStatus => text()(); // UNPAID, PARTIAL, PAID
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- CASH DRAWER & UPI LEDGER ---
class LedgerEntries extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId => text().references(Invoices, #id)();
  RealColumn get amount => real()();
  TextColumn get paymentMode => text()(); // CASH, UPI
  TextColumn get transactionRef => text().nullable()(); // UPI UTR or Cash note
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- RESILIENT OUTBOX SYNC QUEUE ---
class SyncQueue extends Table {
  IntColumn get queueId => integer().autoIncrement()();
  TextColumn get entityType => text()(); // DOSSIER, CASE, EXHIBIT, INVOICE
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // CREATE, UPDATE, DELETE
  TextColumn get payloadJson => text()();
  TextColumn get syncStatus => text()(); // PENDING, PROCESSING, FAILED, SUCCESS
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get scheduledAt => dateTime().withDefault(currentDateAndTime)();
}

```

---

## 5. Subsystems & Operational Utilities

### 5.1 Media Prep Studio

* **Front & Back ID Card Stitcher:** Merges two photo captures onto an A4 or standard ID canvas with automatic border alignment and center folding guides.
* **Target Size Compressor:** Enforces government portal upload bounds (< 200 KB or < 50 KB) using adaptive DCT quantization and resolution downsampling.
* **Passport Photo Studio:** Crops a portrait shot to 35 x 45 mm and tiles 6, 8, or 12 copies on a 4 x 6 inch or A4 photo sheet with cutting markers.

### 5.2 Services Catalog & Auto-Checklist Engine

* When creating a case, the operator checks off services (e.g., *Fresh PAN Card* + *2 Xerox*).
* **Consolidated Document Checklist:** Computes the mathematical union of required documents.
* **Margin Engine:** Computes pass-through government costs vs. net counter profit margin.
* **Document Reuse:** Automatically links past verified exhibits from the customer’s Dossier to the new case without re-scanning.

### 5.3 Billing, Hardware & Comms Engine

* **Dynamic UPI QR Code Generator:** Uses `qr_flutter` to render standard UPI payment links on counter screens or receipt footers.
* **ESC/POS Thermal Printing:** Emits raw ESC/POS byte streams to USB, Bluetooth, or Network receipt printers (58mm/80mm) for 1-second physical receipts.
* **Zero-Cost WhatsApp Intents:** Uses `url_launcher` with pre-filled templates for pickup alerts, balance reminders, and missing document requests without WhatsApp Business API costs.

---

## 6. End-to-End Operational Workflow

[Customer Walks In]
│
▼
[Operator Enters Phone Number]
│
├── Dossier Found ──> Load verified documents from past cases
└── Dossier New   ──> Quick Add: Name + Phone (Local DB commit < 10ms)
│
▼
[New Case: Select Services]
(e.g., PAN Card Application + 2 Xerox + 1 Lamination)
│
▼
[System Auto-Generates Intake]
├── Itemized Estimate calculated: ₹236 (Portal: ₹107 | Shop: ₹129)
├── Merged Document Checklist created: [Aadhaar, Photo, Signature]
└── Advance logged (e.g., ₹100 via UPI) -> Print 58mm Thermal Slip
│
▼
[Document Ingestion Step]
├── Front/Back ID Stitcher merges Aadhaar to 1 page
├── Portal Compressor downsamples output to < 200 KB
└── Missing Doc? ──> 1-Tap WhatsApp Ping to customer
│
▼
[Gov Portal Submission & Ack]
└── Operator enters application number & attaches final Ack slip
│
▼
[Customer Returns for Pickup]
├── 1-Click Batch Print to counter printer
├── Counter screen displays Dynamic UPI QR for remaining balance (₹136)
└── Payment logged -> Case marked CLOSED
│
▼
[Asynchronous Vault Replication Engine]
└── SyncQueue streams exhibits to Google Drive (Free) or R2 Vault (Pro)

---

## 7. Multi-Platform Distribution Architecture

| Target | Build Tooling | Distribution Method | Unique Consideration |
| --- | --- | --- | --- |
| **Android** | `flutter build appbundle` | Google Play Store (`.aab`) | Bluetooth & Camera runtime permissions. |
| **iOS** | `flutter build ipa` | Apple App Store | Sign in with Apple required alongside Google OAuth. |
| **Windows** | `flutter build windows` | Microsoft Store (`.msix`) / Inno Setup (`.exe`) | Direct Win32 USB thermal printer & spool access. |
| **macOS** | `flutter build macos` | Direct Notarized `.dmg` / Mac App Store | Hardened runtime and Apple Notarization ticket. |
| **Web (PWA)** | `flutter build web --wasm` | Static Hosting (Cloudflare Pages / Firebase) | Requires `COOP: same-origin` and `COEP: require-corp` headers for WASM SQLite. |

---

## 8. Phased Engineering Milestones

+-------------------------------------------------------------------------+
| Milestone 1: Multi-Platform Core & Pluggable Storage                    |
| - Drift SQLite setup (Conditional FFI / WASM loaders)                   |
| - Dossiers, Cases, Services, Exhibits, and SyncQueue tables             |
| - Google Drive OAuth (Free) & S3/R2 Presigned Uploader (Pro)            |
+-------------------------------------------------------------------------+
│
▼
+-------------------------------------------------------------------------+
| Milestone 2: Services Catalog, Checklists & Media Prep                  |
| - Services master configuration screen with custom pricing              |
| - Case intake stepper with auto-merged document checklists              |
| - ID Front/Back merger, < 200 KB compressor, 4x6 passport photo grid    |
+-------------------------------------------------------------------------+
│
▼
+-------------------------------------------------------------------------+
| Milestone 3: Billing, POS & Hardware Integration                        |
| - Walk-in POS quick-sale grid for cash transactions                     |
| - Dynamic UPI QR generator & ESC/POS 58mm/80mm receipt driver           |
| - WhatsApp pre-filled template launcher via native deep link            |
+-------------------------------------------------------------------------+
│
▼
+-------------------------------------------------------------------------+
| Milestone 4: Platform Packaging & Production Hardening                  |
| - Windows .msix / Inno Setup installer compilation                      |
| - Android Play Console & Apple App Store review bundles                 |
| - Static Web PWA deployment with OPFS multithreading headers            |
+-------------------------------------------------------------------------+

```

```