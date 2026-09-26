# Dossier: Offline-First CRM & Kiosk Vault

<div align="center">

![Dossier Logo Banner](https://img.shields.io/badge/Dossier-Offline--First%20Kiosk%20CRM-6366F1?style=for-the-badge)
[![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?style=flat&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13+-0175C2?style=flat&logo=dart&logoColor=white)](https://dart.dev)
[![Drift SQLite](https://img.shields.io/badge/Drift-SQLite%20(FFI%20%2B%20WASM)-4479A1?style=flat&logo=sqlite&logoColor=white)](https://drift.simonbinder.eu)
[![Platform Support](https://img.shields.io/badge/Platforms-Windows%20%7C%20Android%20%7C%20macOS%20%7C%20iOS%20%7C%20Web-4EBA6F?style=flat)](https://flutter.dev/multi-platform)

**A high-density, offline-first customer record manager, Point-of-Sale (POS), and document processing workstation tailored for cyber cafes, Common Service Centres (CSCs), and document typing kiosks.**

</div>

---

## 📌 Executive Overview & Core Problem

Cyber cafes, CSC operators, and kiosk centers process hundreds of customer applications daily (PAN cards, voter IDs, government certificates, passport photos, xerox). Operators routinely battle:
1. **Scattered Customer Documents:** Lost scans, repetitive re-scanning of the same customer's Aadhaar across visits.
2. **Strict Government Portal Constraints:** Upload portals rejecting files larger than 200 KB or 50 KB.
3. **Manual Photo Preps:** Tedious manual alignment for ID front/back copies and 4×6 passport photo grid printing.
4. **Cloud Storage Cost & Privacy:** Traditional SaaS charging high monthly hosting fees per gigabyte.

**Dossier solves this** with a zero-cloud-overhead architecture that runs 100% locally on operator workstations with asynchronous cloud vault replication.

---

## 🚀 Key Features

### 🗃️ 1. Offline-First Customer Dossiers & Intake Engine
* **Instant Phone Lookup (< 10ms):** Find repeat customers instantly by phone number and reuse past verified exhibits without re-scanning.
* **Auto-Merged Checklist Engine:** Computes the mathematical union of required documents when bundling multiple services (e.g., *PAN Application + 2 Xerox + Lamination*).
* **Margin & Profit Tracking:** Itemizes pass-through government portal fees vs. counter profit margins.

### 🎨 2. Pure-Dart Media Prep Studio (Background Isolates)
* **ID Card Front/Back Auto-Stitcher:** Combines separate front and back photo captures onto an A4 or standard ID canvas with folding/cutting guidelines.
* **Portal Target-Size Compressor (< 200 KB & < 50 KB):** Enforces portal bounds via binary search DCT quantization and cubic downscaling with zero UI freeze.
* **4×6 Passport Photo Studio:** Generates 6-photo (2×3) or 8-photo (2×4) standard 35×45mm passport grids with scissor guidelines on a single 4×6 inch photo sheet.

### 💳 3. Billing, Hardware & POS Integration
* **Dynamic UPI QR Generator:** Displays instant NPCI-compliant payment QR codes on screen and receipt footers.
* **ESC/POS Thermal Printing:** Direct byte streaming to 58mm and 80mm thermal receipt printers over USB, Bluetooth, or LAN (TCP Port 9100).
* **Zero-Cost WhatsApp Alerts:** 1-tap WhatsApp deep links for "Ready for Pickup" and "Missing Document" alerts without third-party API gateway fees.

---

## 🏛️ Storage Strategy: Free vs. Pro Tier

```
┌───────────────────────────────────────────────────────────────────────────────┐
│                               DOSSIER WORKSTATION                             │
│                         (Drift SQLite + Outbox Queue)                         │
└───────────────────────┬───────────────────────────────────────┬───────────────┘
                        │                                       │
                        ▼ (Free Tier)                           ▼ (Pro Tier)
         ┌─────────────────────────────┐         ┌─────────────────────────────┐
         │     BYO Google Drive v3     │         │    Managed Cloudflare R2    │
         │ - Scope: drive.file         │         │ - Presigned S3 Multipart    │
         │ - Chunked Resumable Uploads │         │ - Zero Egress Fees          │
         │ - Platform Cost: $0.00/mo   │         │ - Multi-Counter Live Sync   │
         └─────────────────────────────┘         └─────────────────────────────┘
```

| Dimension | Free Tier ("Bring Your Own Storage") | Pro Tier (Managed Cloud Vault) |
| :--- | :--- | :--- |
| **Storage Destination** | Operator's Personal Google Drive | Dossier Cloudflare R2 Vault |
| **Monthly Cost** | **₹0 / Forever** | **₹249 – ₹299 / month** |
| **Setup Overhead** | 1-Click Google Sign-In | Zero setup (Instant managed account) |
| **Multi-Counter Sync** | Single workstation | Real-time multi-counter sync (2–4 PCs) |
| **Bandwidth Egress** | Managed by Google | **$0 Egress (Cloudflare R2)** |

---

## 🛠️ Architecture & Tech Stack

```
dossier/
├── lib/
│   ├── app/                    # Theme, app entry point, routing
│   ├── core/                   # Constants, error handling, formatting utilities
│   ├── data/
│   │   ├── local/              # Drift SQLite database, DAOs, schema tables
│   │   ├── remote/             # Google Drive API v3 & Cloudflare R2 S3 connectors
│   │   └── repositories/       # Unified data repositories
│   ├── domain/
│   │   ├── models/             # Domain entities
│   │   └── services/           # Pure-Dart Media Prep, UPI QR, WhatsApp services
│   ├── features/
│   │   ├── dossiers/           # Customer management & search
│   │   ├── cases/              # Case intake & lifecycle stepper
│   │   ├── media_prep/         # ID Stitcher, Compressor, Passport Photo Grid
│   │   └── billing_pos/        # Walk-in POS, Ledger, Thermal receipts
│   └── presentation/           # Adaptive UI components (Desktop 3-Pane vs Mobile Stepper)
├── agentic/
│   ├── design/
│   │   ├── dossier-hld.md      # High-Level Design document
│   │   └── dossier-tech-spec.md# Full Technical Specification (LLD)
│   └── memory.md               # Project state & memory tracker
└── AGENTS.md                   # AI Assistant ground rules & architectural rules
```

* **Framework:** Flutter 3.47+ / Dart 3.13+
* **State Management:** Riverpod 2.x
* **Database Engine:** Drift (Native C-FFI for Desktop/Mobile + WASM with OPFS for Web)
* **Media & Documents:** `image` (Pure Dart), `pdf`, `printing`
* **Hardware & Peripherals:** `flutter_pos_printer_platform_image_3`, `qr_flutter`, `url_launcher`

---

## 🗄️ Relational Data Model (Drift SQLite)

* **`Dossiers`:** Customer master record (ID, name, phone, notes, remote folder ID).
* **`Services`:** Master service catalog (pass-through portal fee, kiosk service fee, required docs JSON).
* **`Cases`:** Customer jobs (`DRAFT` → `DOCS_PENDING` → `READY_TO_APPLY` → `SUBMITTED` → `READY_FOR_PICKUP` → `CLOSED`).
* **`CaseServices`:** Line items connecting cases to services.
* **`Exhibits`:** Document artifacts (`AADHAAR_FRONT`, `PHOTO`, `SIGNATURE`, `ACK_RECEIPT`).
* **`Invoices` & `LedgerEntries`:** Billing records, payment splits (Cash / UPI), and balances.
* **`SyncQueue`:** Outbox table for resilient asynchronous cloud synchronization.

---

## 💻 Getting Started & Development Setup

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.24+ recommended)
* Dart SDK (v3.4+)

### 1. Clone & Install Dependencies
```bash
git clone https://github.com/yogeshraja/dossier.git
cd dossier
flutter pub get
```

### 2. Run Database Code Generator
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Run Locally
* **Desktop (Windows/macOS/Linux):**
  ```bash
  flutter run -d windows # or macos / linux
  ```
* **Mobile (Android/iOS):**
  ```bash
  flutter run -d android # or ios
  ```
* **Web (WASM + OPFS):**
  ```bash
  flutter run -d chrome --wasm
  ```

---

## 📖 Specifications & Documentation

* **High-Level Design (HLD):** [agentic/design/dossier-hld.md](agentic/design/dossier-hld.md)
* **Technical Specification (LLD):** [agentic/design/dossier-tech-spec.md](agentic/design/dossier-tech-spec.md)
* **Engineering Standards:** [AGENTS.md](AGENTS.md)
* **Project State Tracking:** [memory.md](memory.md)

---

## 📄 License

Proprietary — All rights reserved. Built for modern kiosk & cyber center operators.