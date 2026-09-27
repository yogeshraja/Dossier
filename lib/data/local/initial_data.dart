import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:dossier/data/local/app_database.dart';
import 'package:uuid/uuid.dart';

class InitialDataSeeder {
  static Future<void> seedDatabase(AppDatabase db) async {
    const uuid = Uuid();

    // 1. Seed Master Services Catalog if not present
    final servicesCount = await (db.select(db.services)).get();
    if (servicesCount.isEmpty) {
      final defaultServices = [
        ServicesCompanion.insert(
          id: uuid.v4(),
          category: 'GOVT_SCHEME',
          name: 'Fresh PAN Card (NSDL/UTI)',
          defaultPortalFee: const Value(107.0),
          defaultServiceFee: const Value(150.0),
          requiredDocsJson: Value(jsonEncode(['Aadhaar Card (Front & Back)', 'Passport Photo', 'Signature'])),
        ),
        ServicesCompanion.insert(
          id: uuid.v4(),
          category: 'CERTIFICATE',
          name: 'Income & Domicile Certificate',
          defaultPortalFee: const Value(30.0),
          defaultServiceFee: const Value(120.0),
          requiredDocsJson: Value(jsonEncode(['Aadhaar Card', 'Ration Card / Electricity Bill', 'Salary Slip / Affidavit'])),
        ),
        ServicesCompanion.insert(
          id: uuid.v4(),
          category: 'GOVT_SCHEME',
          name: 'Voter ID Card Update / Correction',
          defaultPortalFee: const Value(0.0),
          defaultServiceFee: const Value(100.0),
          requiredDocsJson: Value(jsonEncode(['Aadhaar Card', 'Old Voter Card (if any)', 'Proof of Address'])),
        ),
        ServicesCompanion.insert(
          id: uuid.v4(),
          category: 'PRINTING',
          name: 'Passport Photos (Sheet of 8)',
          defaultPortalFee: const Value(15.0),
          defaultServiceFee: const Value(65.0),
          requiredDocsJson: Value(jsonEncode(['Customer Portrait Capture'])),
        ),
        ServicesCompanion.insert(
          id: uuid.v4(),
          category: 'PRINTING',
          name: 'Xerox Copy (B&W)',
          defaultPortalFee: const Value(0.5),
          defaultServiceFee: const Value(2.5),
          requiredDocsJson: Value(jsonEncode([])),
        ),
        ServicesCompanion.insert(
          id: uuid.v4(),
          category: 'PRINTING',
          name: 'A4 Document Lamination',
          defaultPortalFee: const Value(5.0),
          defaultServiceFee: const Value(25.0),
          requiredDocsJson: Value(jsonEncode([])),
        ),
      ];

      await db.seedInitialServices(defaultServices);
    }
  }

  /// Clean any existing demo/dummy customers
  static Future<void> cleanDummyData(AppDatabase db) async {
    // Delete any old demo customer dossiers if they match dummy names
    await (db.delete(db.dossiers)
          ..where((tbl) => tbl.phoneNumber.isIn(['9876543210', '9123456780', '9988776655'])))
        .go();
  }
}
