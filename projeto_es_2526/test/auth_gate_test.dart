import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/controllers/home_controller.dart';
import 'package:projeto_es_2526/controllers/main_controller.dart';
import 'package:projeto_es_2526/main.dart';
import 'package:projeto_es_2526/models/legal_document.dart';
import 'package:projeto_es_2526/screens/login_screen.dart';
import 'package:projeto_es_2526/screens/main_screen.dart';
import 'package:projeto_es_2526/screens/reaccept_terms_screen.dart';
import 'package:projeto_es_2526/services/auth_service.dart';
import 'package:projeto_es_2526/services/group_service.dart';

HomeController makeHomeController(String userId, FakeFirebaseFirestore store) =>
    HomeController(service: GroupService(firestore: store), userId: userId);

void main() {
  group('AuthGate', () {
    testWidgets('shows LoginScreen when unauthenticated', (tester) async {
      final store = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(signedIn: false);
      final mainController = MainController();
      addTearDown(mainController.dispose);
      // userId is irrelevant here — user is not authenticated
      final homeController = makeHomeController('test-user', store);
      addTearDown(homeController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStream: auth.authStateChanges(),
            mainController: mainController,
            homeController: homeController,
            authService: AuthService(auth: auth, firestore: store),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('shows MainScreen when acceptance is current', (tester) async {
      final store = FakeFirebaseFirestore();
      final mockUser = MockUser();
      await store.collection('users').doc(mockUser.uid).set({
        'termsVersion': LegalDocuments.termsVersion,
        'privacyPolicyVersion': LegalDocuments.privacyPolicyVersion,
      });
      final auth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
      final homeController = makeHomeController(mockUser.uid, store);
      addTearDown(homeController.dispose);
      final mainController = MainController();
      addTearDown(mainController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStream: auth.authStateChanges(),
            mainController: mainController,
            homeController: homeController,
            authService: AuthService(auth: auth, firestore: store),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(ReacceptTermsScreen), findsNothing);
    });

    testWidgets('shows ReacceptTermsScreen when stored version is outdated', (
      tester,
    ) async {
      final store = FakeFirebaseFirestore();
      final mockUser = MockUser();
      await store.collection('users').doc(mockUser.uid).set({
        'termsVersion': '0.0',
        'privacyPolicyVersion': '0.0',
      });
      final auth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
      final homeController = makeHomeController(mockUser.uid, store);
      addTearDown(homeController.dispose);
      final mainController = MainController();
      addTearDown(mainController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStream: auth.authStateChanges(),
            mainController: mainController,
            homeController: homeController,
            authService: AuthService(auth: auth, firestore: store),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReacceptTermsScreen), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);
    });
  });
}
