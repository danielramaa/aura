import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/controllers/home_controller.dart';
import 'package:projeto_es_2526/controllers/main_controller.dart';
import 'package:projeto_es_2526/main.dart';
import 'package:projeto_es_2526/screens/login_screen.dart';
import 'package:projeto_es_2526/screens/main_screen.dart';
import 'package:projeto_es_2526/services/group_service.dart';

HomeController makeHomeController() => HomeController(
  service: GroupService(firestore: FakeFirebaseFirestore()),
  userId: 'test-user',
);

void main() {
  group('AuthGate', () {
    testWidgets('shows LoginScreen when unauthenticated', (tester) async {
      final auth = MockFirebaseAuth(signedIn: false);
      final mainController = MainController();
      addTearDown(mainController.dispose);
      final homeController = makeHomeController();
      addTearDown(homeController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStream: auth.authStateChanges(),
            mainController: mainController,
            homeController: homeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('shows MainScreen when authenticated', (tester) async {
      final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser());
      final homeController = makeHomeController();
      addTearDown(homeController.dispose);
      final mainController = MainController();
      addTearDown(mainController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authStream: auth.authStateChanges(),
            mainController: mainController,
            homeController: homeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MainScreen), findsOneWidget);
    });
  });
}
