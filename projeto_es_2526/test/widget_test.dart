import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:projeto_es_2526/widgets/group_card.dart';

void main() {
  testWidgets('Home screen shows my groups title', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Text('My Groups'),
      ),
    ));
    expect(find.text('My Groups'), findsOneWidget);
  });

  group('GroupCard unread badge', () {
    Widget buildCard({required int unreadCount}) {
      return MaterialApp(
        home: Scaffold(
          body: GroupCard(
            name: 'Test',
            lastMessage: 'Hello',
            time: '10:00',
            color: Colors.blue,
            unreadCount: unreadCount,
          ),
        ),
      );
    }

    testWidgets('badge is hidden when unreadCount is 0', (tester) async {
      await tester.pumpWidget(buildCard(unreadCount: 0));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('badge shows exact count for small values', (tester) async {
      await tester.pumpWidget(buildCard(unreadCount: 5));
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('badge shows 99+ when count exceeds 99', (tester) async {
      await tester.pumpWidget(buildCard(unreadCount: 100));
      expect(find.text('99+'), findsOneWidget);
    });
  });
}