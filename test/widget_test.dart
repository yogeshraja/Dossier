import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dossier/main.dart';

void main() {
  testWidgets('DossierApp launches and displays navigation and intake views', (WidgetTester tester) async {
    // Set desktop screen dimensions (1200x800)
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: DossierApp(),
      ),
    );

    expect(find.text('DOSSIER'), findsOneWidget);
    expect(find.text('Customer Dossiers & Case Intake'), findsOneWidget);
    expect(find.text('New Walk-in Customer'), findsOneWidget);
  });
}
