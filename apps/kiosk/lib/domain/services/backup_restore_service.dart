import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:dossier/data/local/app_database.dart';

class DatabaseBackupBundle {
  final String version;
  final DateTime exportedAt;
  final int totalDossiers;
  final int totalCases;
  final int totalExhibits;
  final int totalInvoices;
  final Map<String, dynamic> data;

  const DatabaseBackupBundle({
    required this.version,
    required this.exportedAt,
    required this.totalDossiers,
    required this.totalCases,
    required this.totalExhibits,
    required this.totalInvoices,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'totalDossiers': totalDossiers,
        'totalCases': totalCases,
        'totalExhibits': totalExhibits,
        'totalInvoices': totalInvoices,
        'data': data,
      };

  String toFormattedJson() => const JsonEncoder.withIndent('  ').convert(toJson());
  Uint8List toBytes() => Uint8List.fromList(utf8.encode(toFormattedJson()));
}

class BackupRestoreService {
  final AppDatabase db;

  BackupRestoreService(this.db);

  /// Exports the entire SQLite database into a portable .dossier backup bundle
  Future<DatabaseBackupBundle> createBackup() async {
    final allDossiers = await db.select(db.dossiers).get();
    final allCases = await db.select(db.cases).get();
    final allExhibits = await db.select(db.exhibits).get();
    final allInvoices = await db.select(db.invoices).get();
    final allServices = await db.select(db.services).get();
    final allLedger = await db.select(db.ledgerEntries).get();

    final data = {
      'dossiers': allDossiers
          .map((d) => {
                'id': d.id,
                'fullName': d.fullName,
                'phoneNumber': d.phoneNumber,
                'email': d.email,
                'notes': d.notes,
                'remoteFolderId': d.remoteFolderId,
                'createdAt': d.createdAt.toIso8601String(),
                'updatedAt': d.updatedAt.toIso8601String(),
              })
          .toList(),
      'cases': allCases
          .map((c) => {
                'id': c.id,
                'dossierId': c.dossierId,
                'title': c.title,
                'stage': c.stage,
                'totalPortalFee': c.totalPortalFee,
                'totalServiceFee': c.totalServiceFee,
                'totalEstimatedAmount': c.totalEstimatedAmount,
                'advancePaid': c.advancePaid,
                'paymentStatus': c.paymentStatus,
                'remoteFolderId': c.remoteFolderId,
                'targetDate': c.targetDate?.toIso8601String(),
                'createdAt': c.createdAt.toIso8601String(),
                'updatedAt': c.updatedAt.toIso8601String(),
              })
          .toList(),
      'exhibits': allExhibits
          .map((e) => {
                'id': e.id,
                'caseId': e.caseId,
                'slotType': e.slotType,
                'fileName': e.fileName,
                'mimeType': e.mimeType,
                'localPath': e.localPath,
                'remoteFileId': e.remoteFileId,
                'fileSizeBytes': e.fileSizeBytes,
                'isStitched': e.isStitched,
                'createdAt': e.createdAt.toIso8601String(),
              })
          .toList(),
      'invoices': allInvoices
          .map((i) => {
                'id': i.id,
                'invoiceNumber': i.invoiceNumber,
                'dossierId': i.dossierId,
                'caseId': i.caseId,
                'invoiceType': i.invoiceType,
                'subtotal': i.subtotal,
                'discount': i.discount,
                'grandTotal': i.grandTotal,
                'amountPaid': i.amountPaid,
                'paymentStatus': i.paymentStatus,
                'createdAt': i.createdAt.toIso8601String(),
              })
          .toList(),
      'services': allServices
          .map((s) => {
                'id': s.id,
                'category': s.category,
                'name': s.name,
                'defaultPortalFee': s.defaultPortalFee,
                'defaultServiceFee': s.defaultServiceFee,
                'requiredDocsJson': s.requiredDocsJson,
                'isArchived': s.isArchived,
                'createdAt': s.createdAt.toIso8601String(),
              })
          .toList(),
      'ledger': allLedger
          .map((l) => {
                'id': l.id,
                'invoiceId': l.invoiceId,
                'amount': l.amount,
                'paymentMode': l.paymentMode,
                'transactionRef': l.transactionRef,
                'recordedAt': l.recordedAt.toIso8601String(),
              })
          .toList(),
    };

    return DatabaseBackupBundle(
      version: '1.0.0',
      exportedAt: DateTime.now(),
      totalDossiers: allDossiers.length,
      totalCases: allCases.length,
      totalExhibits: allExhibits.length,
      totalInvoices: allInvoices.length,
      data: data,
    );
  }

  /// Restores a JSON string or .dossier backup bundle into SQLite database
  Future<Map<String, int>> restoreBackup(String jsonBundleString) async {
    final Map<String, dynamic> bundle = jsonDecode(jsonBundleString);
    final data = bundle['data'] as Map<String, dynamic>? ?? bundle;

    int dossiersRestored = 0;
    int casesRestored = 0;
    int exhibitsRestored = 0;
    int invoicesRestored = 0;

    await db.transaction(() async {
      // 1. Restore Dossiers
      if (data.containsKey('dossiers')) {
        for (final item in (data['dossiers'] as List)) {
          final m = item as Map<String, dynamic>;
          await db.into(db.dossiers).insertOnConflictUpdate(
                DossiersCompanion(
                  id: Value(m['id'] as String),
                  fullName: Value(m['fullName'] as String),
                  phoneNumber: Value(m['phoneNumber'] as String),
                  email: Value(m['email'] as String?),
                  notes: Value(m['notes'] as String?),
                  remoteFolderId: Value(m['remoteFolderId'] as String?),
                  createdAt: Value(DateTime.parse(m['createdAt'] as String)),
                  updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
                ),
              );
          dossiersRestored++;
        }
      }

      // 2. Restore Cases
      if (data.containsKey('cases')) {
        for (final item in (data['cases'] as List)) {
          final m = item as Map<String, dynamic>;
          await db.into(db.cases).insertOnConflictUpdate(
                CasesCompanion(
                  id: Value(m['id'] as String),
                  dossierId: Value(m['dossierId'] as String),
                  title: Value(m['title'] as String),
                  stage: Value(m['stage'] as String? ?? 'DRAFT'),
                  totalPortalFee: Value((m['totalPortalFee'] as num? ?? 0.0).toDouble()),
                  totalServiceFee: Value((m['totalServiceFee'] as num? ?? 0.0).toDouble()),
                  totalEstimatedAmount: Value((m['totalEstimatedAmount'] as num? ?? 0.0).toDouble()),
                  advancePaid: Value((m['advancePaid'] as num? ?? 0.0).toDouble()),
                  paymentStatus: Value(m['paymentStatus'] as String? ?? 'UNPAID'),
                  remoteFolderId: Value(m['remoteFolderId'] as String?),
                  targetDate: Value(m['targetDate'] != null ? DateTime.parse(m['targetDate'] as String) : null),
                  createdAt: Value(DateTime.parse(m['createdAt'] as String)),
                  updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
                ),
              );
          casesRestored++;
        }
      }

      // 3. Restore Exhibits
      if (data.containsKey('exhibits')) {
        for (final item in (data['exhibits'] as List)) {
          final m = item as Map<String, dynamic>;
          await db.into(db.exhibits).insertOnConflictUpdate(
                ExhibitsCompanion(
                  id: Value(m['id'] as String),
                  caseId: Value(m['caseId'] as String),
                  slotType: Value(m['slotType'] as String? ?? 'CUSTOM'),
                  fileName: Value(m['fileName'] as String),
                  mimeType: Value(m['mimeType'] as String),
                  localPath: Value(m['localPath'] as String?),
                  remoteFileId: Value(m['remoteFileId'] as String?),
                  fileSizeBytes: Value(m['fileSizeBytes'] as int? ?? 0),
                  isStitched: Value(m['isStitched'] as bool? ?? false),
                  createdAt: Value(DateTime.parse(m['createdAt'] as String)),
                ),
              );
          exhibitsRestored++;
        }
      }

      // 4. Restore Invoices
      if (data.containsKey('invoices')) {
        for (final item in (data['invoices'] as List)) {
          final m = item as Map<String, dynamic>;
          await db.into(db.invoices).insertOnConflictUpdate(
                InvoicesCompanion(
                  id: Value(m['id'] as String),
                  invoiceNumber: Value(m['invoiceNumber'] as String),
                  dossierId: Value(m['dossierId'] as String?),
                  caseId: Value(m['caseId'] as String?),
                  invoiceType: Value(m['invoiceType'] as String? ?? 'WALK_IN_POS'),
                  subtotal: Value((m['subtotal'] as num? ?? 0.0).toDouble()),
                  discount: Value((m['discount'] as num? ?? 0.0).toDouble()),
                  grandTotal: Value((m['grandTotal'] as num? ?? 0.0).toDouble()),
                  amountPaid: Value((m['amountPaid'] as num? ?? 0.0).toDouble()),
                  paymentStatus: Value(m['paymentStatus'] as String? ?? 'PAID'),
                  createdAt: Value(DateTime.parse(m['createdAt'] as String)),
                ),
              );
          invoicesRestored++;
        }
      }
    });

    return {
      'dossiers': dossiersRestored,
      'cases': casesRestored,
      'exhibits': exhibitsRestored,
      'invoices': invoicesRestored,
    };
  }
}
