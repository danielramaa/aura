import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projeto_es_2526/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom tabs navigate between main sections', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final bottomNav = find.byType(BottomNavigationBar);
    expect(bottomNav, findsOneWidget);

    Future<void> goTo(String label) async {
      await tester.tap(
        find.descendant(of: bottomNav, matching: find.text(label)).first,
      );
      await tester.pumpAndSettle();
    }

    expect(find.text('My Groups'), findsWidgets);

    await goTo('Find Groups');
    expect(find.text('Find Groups'), findsWidgets);

    await goTo('Notifications');
    expect(find.text('Notifications'), findsWidgets);

    await goTo('Profile');
    expect(find.text('Profile'), findsWidgets);

    await goTo('My Groups');
    expect(find.text('My Groups'), findsWidgets);
  });
}
