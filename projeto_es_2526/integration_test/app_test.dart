import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:projeto_es_2526/main.dart' as app;

void main(){
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group("Home page Acceptance Test", () {
    testWidgets('App launches and displays bottom navigation items', (tester) async {

      app.main();
      await tester.pumpAndSettle();

      expect(find.text('My Groups'), findsWidgets);
      expect(find.text('Find Groups'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Home page renders groups list content', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('3 active groups'), findsOneWidget);
      expect(find.text('Diabetes Tipo 2'), findsOneWidget);
      expect(find.text('Hipertensão'), findsOneWidget);
      expect(find.text('Asma'), findsOneWidget);
    });
  });
}