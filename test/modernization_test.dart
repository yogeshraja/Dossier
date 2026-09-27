import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/app/theme.dart';
import 'package:dossier/features/settings/providers/settings_provider.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/widgets/command_palette_dialog.dart';
import 'package:dossier/features/billing_pos/widgets/quick_tender_pad.dart';
import 'package:dossier/presentation/widgets/animated_thermal_receipt.dart';
import 'package:dossier/presentation/widgets/sparkline_chart.dart';
import 'package:dossier/presentation/widgets/case_stage_timeline.dart';
import 'package:dossier/presentation/widgets/kiosk_status_bar.dart';
import 'package:dossier/presentation/widgets/dossier_toast.dart';
import 'package:dossier/features/dossiers/widgets/dossier_list_pane.dart';
import 'package:dossier/features/dossiers/providers/dossier_providers.dart';

void main() {
  group('Modernization Pillar Tests', () {
    testWidgets('1. Glassmorphism & DossierCardVariant.glass renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.darkTheme,
          home: const Scaffold(
            body: Center(
              child: DossierCard(
                variant: DossierCardVariant.glass,
                title: 'Glassmorphic Kiosk Card',
                subtitle: 'Subtle backdrop blur and bevel highlight',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Glassmorphic Kiosk Card'), findsOneWidget);
      expect(find.text('Subtle backdrop blur and bevel highlight'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('2. QuickTenderPad computes change & handles denomination chips', (tester) async {
      double? receivedTendered;
      double? receivedChange;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: QuickTenderPad(
                totalAmount: 130.0,
                onCompletePayment: (tendered, change) {
                  receivedTendered = tendered;
                  receivedChange = change;
                },
              ),
            ),
          ),
        ),
      );

      // Verify total bill is ₹130.00 (both BILL TOTAL and default CASH TENDERED)
      expect(find.text('BILL TOTAL'), findsOneWidget);
      expect(find.text('CASH TENDERED'), findsOneWidget);
      expect(find.text('₹130.00'), findsNWidgets(2));
      expect(find.text('Exact Payment Tendered'), findsOneWidget);

      // Tap the "+₹50" chip
      final plus50 = find.widgetWithText(ActionChip, '+₹50');
      expect(plus50, findsOneWidget);
      await tester.tap(plus50);
      await tester.pump();

      // Tendered should now be 180 (130 + 50) and Return Change should be ₹50.00
      expect(find.text('Return Customer Change'), findsOneWidget);
      expect(find.text('₹50.00'), findsOneWidget);

      // Tap Complete Tender button
      final tenderButton = find.text('Complete Tender (Change ₹50.00)');
      expect(tenderButton, findsOneWidget);
      await tester.tap(tenderButton);
      await tester.pump();

      expect(receivedTendered, 180.0);
      expect(receivedChange, 50.0);
    });

    testWidgets('3. AnimatedThermalReceiptDialog displays items and serrated slip', (tester) async {
      const settings = KioskSettings(
        kioskName: 'Apex Citizen Service Hub',
        kioskAddress: 'Main Market Road, Center #4',
        kioskPhone: '+91 98765 43210',
        merchantUpiVpa: 'apexkiosk@upi',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedThermalReceiptDialog(
                invoiceNumber: 'INV-99001',
                paymentMode: 'CASH',
                subtotal: 100.0,
                grandTotal: 100.0,
                amountTendered: 200.0,
                changeDue: 100.0,
                items: [
                  ReceiptLineItem(
                    title: 'Aadhaar PVC Card',
                    qty: 2,
                    unitPrice: 50.0,
                    total: 100.0,
                  ),
                ],
                customerName: 'Rahul Sharma',
                settings: settings,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('APEX CITIZEN SERVICE HUB'), findsOneWidget);
      expect(find.text('INV-99001'), findsWidgets);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Aadhaar PVC Card x2'), findsOneWidget);
      expect(find.text('TOTAL DUE'), findsOneWidget);
      expect(find.text('Print Slip'), findsOneWidget);
      expect(find.text('Copy Text'), findsOneWidget);
    });

    testWidgets('4. SparklineChart renders hourly sales traffic curve', (tester) async {
      final points = [
        const SparklinePoint(label: '09:00', value: 150.0, count: 2),
        const SparklinePoint(label: '12:00', value: 850.0, count: 8),
        const SparklinePoint(label: '15:00', value: 420.0, count: 4),
        const SparklinePoint(label: '18:00', value: 1200.0, count: 11),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.darkTheme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                child: SparklineChart(
                  points: points,
                  height: 100,
                  currencySymbol: '₹',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('HOURLY REGISTER FLOW'), findsOneWidget);
      expect(find.text('Peak: ₹1200 (18:00)'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('18:00'), findsOneWidget);
    });

    testWidgets('5. CommandPaletteDialog renders and allows fuzzy search filtering', (tester) async {
      int? navigatedTab;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppThemes.darkTheme,
            home: Scaffold(
              body: CommandPaletteDialog(
                onNavigateTab: (tab) => navigatedTab = tab,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check default static actions rendered
      expect(find.text('Go to Dossiers & Case Intake'), findsOneWidget);
      expect(find.text('Go to Quick POS & Billing'), findsOneWidget);
      expect(find.text('Go to Daily Sales Register'), findsOneWidget);

      // Search for "POS"
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);
      await tester.enterText(searchField, 'POS');
      await tester.pumpAndSettle();

      expect(find.text('Go to Quick POS & Billing'), findsOneWidget);
      expect(find.text('Create Quick POS Sale'), findsOneWidget);

      // Tap on "Go to Quick POS & Billing"
      await tester.tap(find.text('Go to Quick POS & Billing'));
      await tester.pumpAndSettle();

      expect(navigatedTab, 2);
    });

    testWidgets('6. CaseStageTimeline renders all milestone stages and triggers onStageChanged', (tester) async {
      String? selectedStage;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemes.darkTheme,
          home: Scaffold(
            body: CaseStageTimeline(
              currentStage: 'DOCS_PENDING',
              uploadedDocsCount: 3,
              totalRequiredDocs: 4,
              onStageChanged: (st) => selectedStage = st,
            ),
          ),
        ),
      );

      // Verify stage titles and document verification counter
      expect(find.text('Docs Needed'), findsWidgets);
      expect(find.text('Intake'), findsWidgets);
      expect(find.text('Ready to Apply'), findsWidgets);
      expect(find.text('Submitted'), findsWidgets);
      expect(find.text('Ready for Pickup'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Docs: 3/4 (75%)'), findsOneWidget);

      // Tap on 'Ready to Apply' step node
      await tester.tap(find.text('Ready to Apply').first);
      await tester.pumpAndSettle();

      expect(selectedStage, 'READY_TO_APPLY');
    });

    testWidgets('7. KioskStatusBar displays offline/synced pill and opens diagnostics', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingSyncQueueStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: KioskStatusBar(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Offline Vault'), findsOneWidget);
      expect(find.text('POS 58/80'), findsOneWidget);

      // Tap the status bar to open diagnostics
      await tester.tap(find.byType(KioskStatusBar));
      await tester.pumpAndSettle();

      expect(find.text('Kiosk Hardware & Vault Diagnostics'), findsOneWidget);
      expect(find.text('Cloud Vault Engine'), findsOneWidget);
      expect(find.text('ESC/POS Thermal Printer'), findsOneWidget);
      expect(find.text('DRIVER READY'), findsOneWidget);
    });

    testWidgets('8. DossierToast renders and invokes action callbacks', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  DossierToast.show(
                    context,
                    title: 'Customer Case Synced',
                    message: 'Uploaded exhibits to Google Drive',
                    variant: DossierToastVariant.success,
                    actionLabel: 'View Receipt',
                    onAction: () => actionTriggered = true,
                  );
                },
                child: const Text('Show Toast'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Toast'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Customer Case Synced'), findsOneWidget);
      expect(find.text('Uploaded exhibits to Google Drive'), findsOneWidget);
      expect(find.text('View Receipt'), findsOneWidget);

      await tester.tap(find.text('View Receipt'));
      await tester.pump();

      expect(actionTriggered, isTrue);
    });

    testWidgets('9. DossierListPane displays filter chips for All, Active Jobs, Pending Docs, and Unpaid Dues', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dossiersStreamProvider.overrideWith((ref) => Stream.value([])),
            allCasesStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DossierListPane(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dossiers'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Active Jobs'), findsOneWidget);
      expect(find.text('Pending Docs'), findsOneWidget);
      expect(find.text('Unpaid Dues'), findsOneWidget);

      // Tap on 'Pending Docs' chip
      await tester.tap(find.text('Pending Docs'));
      await tester.pumpAndSettle();
    });
  });
}

