import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:projeto_es_2526/widgets/group_card.dart';
import 'package:projeto_es_2526/main.dart';

void main() {
  testWidgets('App starts on home with bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('My Groups'), findsWidgets);
    expect(find.text('Find Groups'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Bottom navigation changes visible screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    final bottomNav = find.byType(BottomNavigationBar);

    await tester.tap(
      find.descendant(of: bottomNav, matching: find.text('Find Groups')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Find Groups'), findsWidgets);

    await tester.tap(
      find.descendant(of: bottomNav, matching: find.text('Notifications')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsWidgets);

    await tester.tap(
      find.descendant(of: bottomNav, matching: find.text('Profile')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsWidgets);
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

    testWidgets('online and member text reflect card state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupCard(
              name: 'Test',
              lastMessage: 'Hello',
              time: '10:00',
              color: Colors.blue,
              isOnline: true,
              memberCount: 2400,
            ),
          ),
        ),
      );

      expect(find.text('Online now'), findsOneWidget);
      expect(find.text('2400 members'), findsOneWidget);
      expect(find.text('Nobody online'), findsNothing);
    });
  });
}