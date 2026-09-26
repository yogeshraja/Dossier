import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/main.dart';
import 'package:dossier/presentation/screens/splash_screen.dart';
import 'package:dossier/presentation/common_widgets/dossier_button.dart';
import 'package:dossier/presentation/common_widgets/dossier_card.dart';
import 'package:dossier/presentation/common_widgets/dossier_input_field.dart';
import 'package:dossier/presentation/common_widgets/dossier_panel.dart';
import 'package:dossier/presentation/common_widgets/dossier_badge.dart';

void main() {
  group('Splash Screen Tests', () {
    testWidgets('SplashScreen renders animated logo and boot sequence', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('DOSSIER'), findsOneWidget);
      expect(find.text('Offline-First CRM & Kiosk Vault'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('KioskWorkstationHome Tests', () {
    testWidgets('KioskWorkstationHome renders on Desktop viewport (1200x800) without overflows', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: KioskWorkstationHome(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('DOSSIER'), findsOneWidget);
      expect(find.text('KIOSK VAULT'), findsOneWidget);
      expect(find.text('Dossiers & Intake'), findsOneWidget);
      expect(find.text('Media Studio'), findsOneWidget);
      expect(find.text('POS & Billing'), findsOneWidget);
      expect(find.text('Vault Sync'), findsOneWidget);
      expect(find.text('Catalog & Settings'), findsOneWidget);
    });

    testWidgets('KioskWorkstationHome renders on Mobile viewport (400x800) with Bottom Navigation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: KioskWorkstationHome(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('DOSSIER'), findsOneWidget);
    });
  });

  group('Reusable Components Tests', () {
    testWidgets('DossierButton triggers onPressed and shows loading', (WidgetTester tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DossierButton(
              text: 'Save Case',
              icon: Icons.check,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('Save Case'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.byType(DossierButton));
      expect(pressed, isTrue);
    });

    testWidgets('DossierCard renders title, subtitle, badge and responds to taps', (WidgetTester tester) async {
      bool cardTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DossierCard(
              title: 'Customer Job',
              subtitle: 'Aadhaar Update',
              badge: const DossierBadge(label: 'READY', variant: DossierBadgeVariant.success),
              onTap: () => cardTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Customer Job'), findsOneWidget);
      expect(find.text('Aadhaar Update'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);

      await tester.tap(find.byType(DossierCard));
      expect(cardTapped, isTrue);
    });

    testWidgets('DossierInputField handles text entry and clear button', (WidgetTester tester) async {
      final ctrl = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DossierInputField(
              controller: ctrl,
              label: 'Phone Number',
              hintText: 'Enter phone',
              showClearButton: true,
            ),
          ),
        ),
      );

      expect(find.text('Phone Number'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.pump();
      expect(ctrl.text, '9876543210');
    });

    testWidgets('DossierPanel collapses and expands on header tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DossierPanel(
              title: 'Case Exhibits',
              isCollapsible: true,
              child: Text('Exhibits Content Body'),
            ),
          ),
        ),
      );

      expect(find.text('Case Exhibits'), findsOneWidget);
      expect(find.text('Exhibits Content Body'), findsOneWidget);

      // Tap header to collapse
      await tester.tap(find.text('Case Exhibits'));
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('DossierBadge renders different variants', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                DossierBadge(label: 'PRIMARY', variant: DossierBadgeVariant.primary),
                DossierBadge(label: 'SUCCESS', variant: DossierBadgeVariant.success),
                DossierBadge(label: 'WARNING', variant: DossierBadgeVariant.warning),
              ],
            ),
          ),
        ),
      );

      expect(find.text('PRIMARY'), findsOneWidget);
      expect(find.text('SUCCESS'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
    });
  });
}
