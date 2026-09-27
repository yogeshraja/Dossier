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
  });
}
