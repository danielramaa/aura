import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projeto_es_2526/controllers/home_controller.dart';
import 'package:projeto_es_2526/controllers/main_controller.dart';
import 'package:projeto_es_2526/controllers/profile_controller.dart';
import 'package:projeto_es_2526/screens/main_screen.dart';
import 'package:projeto_es_2526/services/group_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('bottom tabs navigate between main sections', (tester) async {
    final auth = MockFirebaseAuth(signedIn: true);
    final firestore = FakeFirebaseFirestore();
    final mainController = MainController();
    final homeController = HomeController(
      service: GroupService(firestore: firestore),
    );
    final profileController = ProfileController(
      auth: auth,
      firestore: firestore,
    );
    addTearDown(mainController.dispose);
    addTearDown(homeController.dispose);
    addTearDown(profileController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(
          mainController: mainController,
          homeController: homeController,
          profileController: profileController,
        ),
      ),
    );
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
