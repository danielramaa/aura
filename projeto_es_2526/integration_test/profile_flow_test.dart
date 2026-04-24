import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projeto_es_2526/controllers/profile_controller.dart';
import 'package:projeto_es_2526/screens/profile_screen.dart';

Future<void> _waitForCommunities(ProfileController controller) async {
  while (controller.isLoadingCommunities) {
    await Future.delayed(Duration.zero);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Profile screen flow', () {
    testWidgets('shows "not logged in" message when user is null',
        (tester) async {
      final controller = ProfileController(
        auth: MockFirebaseAuth(signedIn: false),
        firestore: FakeFirebaseFirestore(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: ProfileScreen(controller: controller),
      ));
      await tester.pumpAndSettle();

      expect(find.text('User not logged in.'), findsOneWidget);
    });

    testWidgets('renders user email and empty community list',
        (tester) async {
      final controller = ProfileController(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: 'me@example.com'),
        ),
        firestore: FakeFirebaseFirestore(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: ProfileScreen(controller: controller),
      ));
      await tester.pumpAndSettle();

      expect(find.text('me@example.com'), findsOneWidget);
      expect(
        find.text('You have not joined any communities yet.'),
        findsOneWidget,
      );
    });

    testWidgets('lists joined communities after loading', (tester) async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g1').set({
        'name': 'Mindfulness',
        'description': '',
        'memberCount': 10,
        'color': 0xFF378ADD,
      });
      await firestore
          .collection('users')
          .doc('u1')
          .collection('anonymousIdentities')
          .doc('g1')
          .set({'nickname': 'CalmOwl12'});

      final controller = ProfileController(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: 'me@example.com'),
        ),
        firestore: firestore,
      );
      addTearDown(controller.dispose);
      await _waitForCommunities(controller);

      await tester.pumpWidget(MaterialApp(
        home: ProfileScreen(controller: controller),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mindfulness'), findsOneWidget);
    });

    testWidgets('tapping logout signs the user out', (tester) async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'me@example.com'),
      );
      final controller = ProfileController(
        auth: auth,
        firestore: FakeFirebaseFirestore(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        home: ProfileScreen(controller: controller),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
      await tester.pumpAndSettle();

      expect(auth.currentUser, isNull);
    });
  });
}
