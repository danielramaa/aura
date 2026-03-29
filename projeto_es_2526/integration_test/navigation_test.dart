
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projeto_es_2526/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Bottom Navigation Acceptance Test', () {
    testWidgets('User can navigate through all bottom tabs', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      expect(find.text('My Groups'), findsWidgets);

      await tester.tap(find.text('Find Groups'));
      await tester.pumpAndSettle();

      expect(find.text('Find Groups'), findsWidgets);

      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsWidgets);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsWidgets);

      await tester.tap(find.text('My Groups').first);
      await tester.pumpAndSettle();

      expect(find.text('My Groups'), findsWidgets);
    });
  });
}