import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projeto_es_2526/controllers/home_controller.dart';
import 'package:projeto_es_2526/controllers/main_controller.dart';
import 'package:projeto_es_2526/main.dart';
import 'package:projeto_es_2526/screens/login_screen.dart';
import 'package:projeto_es_2526/screens/main_screen.dart';
import 'package:projeto_es_2526/services/auth_service.dart';
import 'package:projeto_es_2526/services/group_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

HomeController _homeController(FakeFirebaseFirestore firestore) =>
    HomeController(
      service: GroupService(firestore: firestore),
      userId: 'test-user',
    );

Widget _buildGate({
  required MockFirebaseAuth auth,
  required MainController mainController,
  required HomeController homeController,
}) {
  return MaterialApp(
    home: AuthGate(
      authStream: auth.authStateChanges(),
      mainController: mainController,
      homeController: homeController,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('full flow: register → MainScreen → logout → LoginScreen', (
    tester,
  ) async {
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'test-user'));
    final firestore = FakeFirebaseFirestore();
    final authService = AuthService(auth: auth);
    final mainController = MainController();
    final homeController = _homeController(firestore);
    addTearDown(mainController.dispose);
    addTearDown(homeController.dispose);

    await tester.pumpWidget(
      _buildGate(
        auth: auth,
        mainController: mainController,
        homeController: homeController,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    await authService.register(
      'new@example.com',
      'password123',
      dateOfBirth: DateTime(2000, 1, 1),
      acceptedTerms: true,
    );
    await tester.pumpAndSettle();
    expect(find.byType(MainScreen), findsOneWidget);

    await authService.logout();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('login flow: LoginScreen form accepts credentials and signs in', (
    tester,
  ) async {
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'test-user'));
    final firestore = FakeFirebaseFirestore();
    final authService = AuthService(auth: auth);
    final mainController = MainController();
    final homeController = _homeController(firestore);
    addTearDown(mainController.dispose);
    addTearDown(homeController.dispose);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: authService)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();

    expect(auth.currentUser, isNotNull);
  });

  testWidgets('LoginScreen — toggle between Login and Register', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();
    final authService = AuthService(auth: auth);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: authService)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('LoginScreen — invalid email shows validation error', (
    tester,
  ) async {
    final auth = MockFirebaseAuth();
    final authService = AuthService(auth: auth);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: authService)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'not-an-email',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });
}
