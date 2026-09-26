import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:dossier/data/local/app_database.dart';
import 'package:uuid/uuid.dart';

class InitialDataSeeder {
  static Future<void> seedDatabase(AppDatabase db) async {
    const uuid = Uuid();

    // 1. Seed Master Services
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

    // 2. Seed Demo Customers if empty
    final dossiersCount = await (db.select(db.dossiers)).get();
    if (dossiersCount.isEmpty) {
      final customer1Id = uuid.v4();
      final customer2Id = uuid.v4();
      final customer3Id = uuid.v4();

      await db.insertDossier(
        DossiersCompanion.insert(
          id: customer1Id,
          fullName: 'Ramesh Sharma',
          phoneNumber: '9876543210',
          email: const Value('ramesh.sharma@example.com'),
          notes: const Value('Regular customer from Sector 4. Prefers WhatsApp updates.'),
        ),
      );

      await db.insertDossier(
        DossiersCompanion.insert(
          id: customer2Id,
          fullName: 'Pooja Verma',
          phoneNumber: '9123456780',
          email: const Value('pooja.v@example.com'),
          notes: const Value('Urgent application for university admissions.'),
        ),
      );

      await db.insertDossier(
        DossiersCompanion.insert(
          id: customer3Id,
          fullName: 'Amit Kumar Patel',
          phoneNumber: '9988776655',
          email: const Value('amit.patel@example.com'),
          notes: const Value('Kiosk loyalty card holder.'),
        ),
      );

      // Seed a case for Ramesh Sharma
      final case1Id = uuid.v4();
      await db.insertCase(
        CasesCompanion.insert(
          id: case1Id,
          dossierId: customer1Id,
          title: 'Fresh PAN Card Application + 4 Xerox',
          stage: const Value('DOCS_PENDING'),
          totalPortalFee: const Value(107.0),
          totalServiceFee: const Value(160.0),
          totalEstimatedAmount: const Value(267.0),
          advancePaid: const Value(100.0),
          paymentStatus: const Value('PARTIALLY_PAID'),
        ),
      );

      // Seed a case for Pooja Verma (Ready for Pickup)
      final case2Id = uuid.v4();
      await db.insertCase(
        CasesCompanion.insert(
          id: case2Id,
          dossierId: customer2Id,
          title: 'Income Certificate Form Submission',
          stage: const Value('READY_FOR_PICKUP'),
          totalPortalFee: const Value(30.0),
          totalServiceFee: const Value(120.0),
          totalEstimatedAmount: const Value(150.0),
          advancePaid: const Value(50.0),
          paymentStatus: const Value('PARTIALLY_PAID'),
        ),
      );
    }
  }
}
