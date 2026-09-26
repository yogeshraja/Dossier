import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/main.dart';

void main() {
  testWidgets('DossierApp launches and renders workstation navigation and panes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: DossierApp(),
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
}
