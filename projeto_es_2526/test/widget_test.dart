import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:projeto_es_2526/controllers/home_controller.dart';
import 'package:projeto_es_2526/controllers/main_controller.dart';
import 'package:projeto_es_2526/controllers/profile_controller.dart';
import 'package:projeto_es_2526/models/message.dart';
import 'package:projeto_es_2526/widgets/message_bubble.dart';
import 'package:projeto_es_2526/screens/main_screen.dart';
import 'package:projeto_es_2526/services/group_service.dart';
import 'package:projeto_es_2526/services/identity_service.dart';
import 'package:projeto_es_2526/widgets/group_card.dart';

Widget buildApp(
  HomeController homeController,
  ProfileController profileController,
) {
  final firestore = FakeFirebaseFirestore();
  final auth = MockFirebaseAuth(signedIn: false);
  return MaterialApp(
    home: MainScreen(
      mainController: MainController(),
      homeController: homeController,
      profileController: profileController,
      findGroupsService: GroupService(firestore: firestore),
      findGroupsIdentityService: IdentityService(firestore: firestore),
      findGroupsAuth: auth,
    ),
  );
}

HomeController makeHomeController() => HomeController(
  service: GroupService(firestore: FakeFirebaseFirestore()),
  userId: 'test-user',
);

ProfileController makeProfileController() => ProfileController(
  auth: MockFirebaseAuth(),
  firestore: FakeFirebaseFirestore(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('App starts on home with bottom navigation', (
    WidgetTester tester,
  ) async {
    final homeController = makeHomeController();
    final profileController = makeProfileController();
    addTearDown(homeController.dispose);
    addTearDown(profileController.dispose);

    await tester.pumpWidget(buildApp(homeController, profileController));
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
    final homeController = makeHomeController();
    final profileController = makeProfileController();
    addTearDown(homeController.dispose);
    addTearDown(profileController.dispose);

    await tester.pumpWidget(buildApp(homeController, profileController));
    await tester.pumpAndSettle();

    final bottomNav = find.byType(BottomNavigationBar);

    await tester.tap(
      find.descendant(of: bottomNav, matching: find.text('Find Groups')).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Find Groups'), findsWidgets);

    await tester.tap(
      find
          .descendant(of: bottomNav, matching: find.text('Notifications'))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('No new notifications'), findsOneWidget);

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

  group('buildMentionSpans', () {
    test('plain text with no @-tokens produces a single plain span', () {
      final spans = buildMentionSpans('hello world', []);
      expect(spans.length, 1);
      expect(spans.first.text, 'hello world');
      expect(spans.first.style?.color, Colors.black87);
    });

    test('valid mention is highlighted in blue bold', () {
      final spans = buildMentionSpans('@Alice hi', ['Alice']);
      final mention = spans.firstWhere((s) => s.text == '@Alice');
      expect(mention.style?.color, const Color(0xFF185FA5));
      expect(mention.style?.fontWeight, FontWeight.bold);
    });

    test('unknown @-token is rendered as plain text, not highlighted', () {
      final spans = buildMentionSpans('@Nobody', []);
      final token = spans.firstWhere((s) => s.text == '@Nobody');
      expect(token.style?.color, Colors.black87);
      expect(token.style?.fontWeight, isNot(FontWeight.bold));
    });

    test('mention at the start of the message has no leading span', () {
      final spans = buildMentionSpans('@Alice', ['Alice']);
      expect(spans.length, 1);
      expect(spans.first.text, '@Alice');
    });

    test('mention at the end of the message has a leading plain span', () {
      final spans = buildMentionSpans('hey @Bob', ['Bob']);
      expect(spans.length, 2);
      expect(spans.first.text, 'hey ');
      expect(spans.last.text, '@Bob');
    });

    test('multiple mentions are each individually highlighted', () {
      final spans = buildMentionSpans('@Alice and @Bob', ['Alice', 'Bob']);
      final highlighted = spans.where(
        (s) => s.style?.color == const Color(0xFF185FA5),
      );
      expect(highlighted.map((s) => s.text), containsAll(['@Alice', '@Bob']));
    });

    test('only valid mentions highlighted when mixed with unknown tokens', () {
      final spans = buildMentionSpans('@Alice @Ghost', ['Alice']);
      final alice = spans.firstWhere((s) => s.text == '@Alice');
      final ghost = spans.firstWhere((s) => s.text == '@Ghost');
      expect(alice.style?.color, const Color(0xFF185FA5));
      expect(ghost.style?.color, Colors.black87);
    });
  });

  group('MessageBubble', () {
    testWidgets('tapping a sender nickname triggers onSenderTap', (
      tester,
    ) async {
      var tapped = false;
      final message = Message(
        id: 'm1',
        text: 'hello',
        anonymousId: 'anon-1',
        senderNickname: 'BraveOwl7',
        senderAvatarIndex: 0,
        timestamp: Timestamp.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: message,
              isOwn: false,
              isSenderMedic: false,
              isPinned: false,
              isHighlighted: false,
              currentAnonymousId: 'anon-current',
              hasReactionError: false,
              isRetryingReaction: false,
              onShowOptions: () {},
              onReply: () {},
              onSenderTap: () => tapped = true,
              onToggleReaction: (_) {},
              onRetryReaction: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('BraveOwl7'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tapped, isTrue);
    });
  });
}
