import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/data/local/app_database.dart';

// Database Instance Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// Search Query State
final dossierSearchQueryProvider = StateProvider<String>((ref) => '');

// Dossier Filter Category
enum DossierFilterCategory {
  all('All'),
  activeJobs('Active Jobs'),
  pendingDocs('Pending Docs'),
  unpaidDues('Unpaid Dues');

  final String label;
  const DossierFilterCategory(this.label);
}

final dossierFilterProvider = StateProvider<DossierFilterCategory>((ref) => DossierFilterCategory.all);

// Reactive Dossiers List
final dossiersStreamProvider = StreamProvider<List<Dossier>>((ref) {
  final db = ref.watch(databaseProvider);
  final query = ref.watch(dossierSearchQueryProvider);
  return db.searchDossiers(query);
});

// All Cases in System Stream
final allCasesStreamProvider = StreamProvider<List<Case>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllCases();
});

// Selected Dossier State
final activeDossierIdProvider = StateProvider<String?>((ref) => null);

final activeDossierProvider = Provider<Dossier?>((ref) {
  final activeId = ref.watch(activeDossierIdProvider);
  final dossiersAsync = ref.watch(dossiersStreamProvider);
  return dossiersAsync.when(
    data: (dossiers) {
      if (activeId == null && dossiers.isNotEmpty) {
        return dossiers.first;
      }
      return dossiers.where((d) => d.id == activeId).firstOrNull ?? (dossiers.isNotEmpty ? dossiers.first : null);
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

// Reactive Cases for Active Customer
final activeCasesStreamProvider = StreamProvider<List<Case>>((ref) {
  final db = ref.watch(databaseProvider);
  final activeDossier = ref.watch(activeDossierProvider);
  if (activeDossier == null) return Stream.value([]);
  return db.watchCasesForDossier(activeDossier.id);
});

// Selected Active Case State
final activeCaseIdProvider = StateProvider<String?>((ref) => null);

final activeCaseProvider = Provider<Case?>((ref) {
  final activeCaseId = ref.watch(activeCaseIdProvider);
  final casesAsync = ref.watch(activeCasesStreamProvider);
  return casesAsync.when(
    data: (cases) {
      if (activeCaseId == null && cases.isNotEmpty) {
        return cases.first;
      }
      return cases.where((c) => c.id == activeCaseId).firstOrNull ?? (cases.isNotEmpty ? cases.first : null);
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

// Exhibits for Active Case
final activeCaseExhibitsStreamProvider = StreamProvider<List<Exhibit>>((ref) {
  final db = ref.watch(databaseProvider);
  final activeCase = ref.watch(activeCaseProvider);
  if (activeCase == null) return Stream.value([]);
  return db.watchExhibitsForCase(activeCase.id);
});

// Services Master Catalog Stream
final activeServicesStreamProvider = StreamProvider<List<Service>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchActiveServices();
});

// Outbox Sync Queue Stream
final pendingSyncQueueStreamProvider = StreamProvider<List<SyncQueueData>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchPendingSyncItems();
});

// Recent Invoices Stream
final recentInvoicesStreamProvider = StreamProvider<List<Invoice>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecentInvoices();
});
