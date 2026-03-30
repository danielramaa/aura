import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projeto_es_2526/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Cenário: Navegação entre Home e Descoberta de Grupos', () {
    testWidgets('Deve clicar no ícone de busca e validar a mudança de ecrã', (WidgetTester tester) async {
      app.main();
      
      await tester.pumpAndSettle();

      expect(find.text('Diabetes Tipo 2'), findsOneWidget);


      final Finder searchIcon = find.byIcon(Icons.search);
      expect(searchIcon, findsWidgets);

      await tester.tap(searchIcon.first);

      await tester.pumpAndSettle();


      expect(find.text('Find Groups'), findsOneWidget);
    });
  });
}