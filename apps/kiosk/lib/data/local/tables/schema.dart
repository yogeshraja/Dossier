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
  TextColumn get requiredDocsJson => text().withDefault(const Constant('[]'))(); // JSON array e.g. ['AADHAAR', 'PHOTO']
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
  TextColumn get stage => text().withDefault(const Constant('DRAFT'))(); // DRAFT, DOCS_PENDING, READY_TO_APPLY, SUBMITTED, READY_FOR_PICKUP, CLOSED
  RealColumn get totalPortalFee => real().withDefault(const Constant(0.0))();
  RealColumn get totalServiceFee => real().withDefault(const Constant(0.0))();
  RealColumn get totalEstimatedAmount => real().withDefault(const Constant(0.0))();
  RealColumn get advancePaid => real().withDefault(const Constant(0.0))();
  TextColumn get paymentStatus => text().withDefault(const Constant('UNPAID'))(); // UNPAID, PARTIALLY_PAID, PAID
  TextColumn get remoteFolderId => text().nullable()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- CASE SERVICES (LINE ITEMS PER CASE) ---
class CaseServices extends Table {
  TextColumn get id => text()(); // UUID v4
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
  TextColumn get id => text()(); // UUID v4
  TextColumn get caseId => text().references(Cases, #id)();
  TextColumn get slotType => text()(); // AADHAAR_FRONT, AADHAAR_BACK, PHOTO, SIGNATURE, ACK_RECEIPT, CUSTOM
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
  TextColumn get id => text()(); // UUID v4
  TextColumn get invoiceNumber => text().unique()(); // e.g., INV-2026-0042
  TextColumn get dossierId => text().nullable().references(Dossiers, #id)();
  TextColumn get caseId => text().nullable().references(Cases, #id)();
  TextColumn get invoiceType => text()(); // WALK_IN_POS, CASE_INVOICE
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get grandTotal => real()();
  RealColumn get amountPaid => real().withDefault(const Constant(0.0))();
  TextColumn get paymentStatus => text().withDefault(const Constant('UNPAID'))(); // UNPAID, PARTIAL, PAID
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- CASH DRAWER & UPI LEDGER ---
class LedgerEntries extends Table {
  TextColumn get id => text()(); // UUID v4
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
  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))(); // PENDING, PROCESSING, FAILED, SUCCESS
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get scheduledAt => dateTime().withDefault(currentDateAndTime)();
}
