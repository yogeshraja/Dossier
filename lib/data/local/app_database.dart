import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:dossier/data/local/tables/schema.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Dossiers,
  Services,
  Cases,
  CaseServices,
  Exhibits,
  Invoices,
  LedgerEntries,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'dossier_vault_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
        onResult: (result) {
          if (result.missingFeatures.isNotEmpty) {
            // Log missing web features if any
          }
        },
      ),
    );
  }

  // --- Core DAOs & Helper Queries ---

  // 1. Dossier (Customer) Operations
  Stream<List<Dossier>> watchAllDossiers() => select(dossiers).watch();
  
  Stream<List<Dossier>> searchDossiers(String query) {
    if (query.trim().isEmpty) return watchAllDossiers();
    final wildcard = '%${query.trim()}%';
    return (select(dossiers)
          ..where((tbl) => tbl.fullName.like(wildcard) | tbl.phoneNumber.like(wildcard)))
        .watch();
  }

  Future<Dossier?> getDossierByPhone(String phone) {
    return (select(dossiers)..where((tbl) => tbl.phoneNumber.equals(phone)))
        .getSingleOrNull();
  }

  Future<int> insertDossier(DossiersCompanion entry) => into(dossiers).insert(entry);
  Future<bool> updateDossier(DossiersCompanion entry) => update(dossiers).replace(entry);

  // 2. Services Master Operations
  Stream<List<Service>> watchActiveServices() {
    return (select(services)..where((tbl) => tbl.isArchived.equals(false))).watch();
  }

  Future<int> insertService(ServicesCompanion entry) => into(services).insert(entry);
  Future<void> seedInitialServices(List<ServicesCompanion> defaultList) async {
    await batch((batch) {
      batch.insertAll(services, defaultList, mode: InsertMode.insertOrIgnore);
    });
  }

  // 3. Cases & Job Lifecycle
  Stream<List<Case>> watchCasesForDossier(String dossierId) {
    return (select(cases)
          ..where((tbl) => tbl.dossierId.equals(dossierId))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }

  Stream<List<Case>> watchCasesByStage(String stage) {
    return (select(cases)
          ..where((tbl) => tbl.stage.equals(stage))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }

  Future<int> insertCase(CasesCompanion entry) => into(cases).insert(entry);
  Future<int> updateCaseStage(String caseId, String stage) {
    return (update(cases)..where((tbl) => tbl.id.equals(caseId))).write(
      CasesCompanion(
        stage: Value(stage),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // 4. Exhibits & Artifacts
  Stream<List<Exhibit>> watchExhibitsForCase(String caseId) {
    return (select(exhibits)..where((tbl) => tbl.caseId.equals(caseId))).watch();
  }

  Future<int> insertExhibit(ExhibitsCompanion entry) => into(exhibits).insert(entry);
  Future<int> deleteExhibit(String exhibitId) =>
      (delete(exhibits)..where((tbl) => tbl.id.equals(exhibitId))).go();
  Future<int> deleteCase(String caseId) =>
      (delete(cases)..where((tbl) => tbl.id.equals(caseId))).go();
  Future<int> deleteDossier(String dossierId) =>
      (delete(dossiers)..where((tbl) => tbl.id.equals(dossierId))).go();

  // 5. Invoicing & Ledger
  Stream<List<Invoice>> watchRecentInvoices({int limit = 50}) {
    return (select(invoices)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<int> insertInvoice(InvoicesCompanion entry) => into(invoices).insert(entry);
  Future<int> insertLedgerEntry(LedgerEntriesCompanion entry) => into(ledgerEntries).insert(entry);

  // 6. Outbox Sync Queue
  Stream<List<SyncQueueData>> watchPendingSyncItems() {
    return (select(syncQueue)
          ..where((tbl) => tbl.syncStatus.equals('PENDING'))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.scheduledAt)]))
        .watch();
  }

  Future<int> enqueueSyncItem(SyncQueueCompanion entry) => into(syncQueue).insert(entry);
  Future<int> markSyncSuccess(int queueId) {
    return (update(syncQueue)..where((tbl) => tbl.queueId.equals(queueId))).write(
      const SyncQueueCompanion(syncStatus: Value('SUCCESS')),
    );
  }
}
