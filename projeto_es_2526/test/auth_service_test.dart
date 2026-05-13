import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthService — authentication', () {
    test('currentUser is null when not signed in', () {
      final service = AuthService(auth: MockFirebaseAuth(signedIn: false));
      expect(service.currentUser, isNull);
    });

    test('currentUser returns user when signed in', () {
      final service = AuthService(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
        ),
      );
      expect(service.currentUser, isNotNull);
      expect(service.currentUser!.email, 'user@example.com');
    });

    test('login signs in with email/password', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
      );
      final service = AuthService(auth: auth);

      final credential = await service.login('user@example.com', 'password123');
      expect(credential.user, isNotNull);
      expect(auth.currentUser, isNotNull);
    });

    test('register creates a new account', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'new@example.com'),
      );
      final service = AuthService(auth: auth);

      final credential = await service.register(
        'new@example.com',
        'password123',
      );
      expect(credential.user, isNotNull);
      expect(auth.currentUser, isNotNull);
    });

    test('logout clears the current user', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
      );
      final service = AuthService(auth: auth);

      expect(service.currentUser, isNotNull);
      await service.logout();
      expect(service.currentUser, isNull);
    });

    test('sendPasswordResetEmail completes without error', () async {
      final service = AuthService(auth: MockFirebaseAuth());
      await expectLater(
        service.sendPasswordResetEmail('user@example.com'),
        completes,
      );
    });

    test('authStateChanges emits user updates', () async {
      final auth = MockFirebaseAuth();
      final service = AuthService(auth: auth);
      final states = <bool>[];
      final sub = service.authStateChanges.listen(
        (user) => states.add(user != null),
      );
      await service.register('a@b.com', 'password123');
      await Future.delayed(Duration.zero);
      await service.logout();
      await Future.delayed(Duration.zero);
      await sub.cancel();
      expect(states, contains(true));
      expect(states, contains(false));
    });
  });

  group('AuthService — stayLoggedIn preference', () {
    test('defaults to true when not set', () async {
      final service = AuthService(auth: MockFirebaseAuth());
      expect(await service.getStayLoggedIn(), isTrue);
    });

    test('persists false after being set', () async {
      final service = AuthService(auth: MockFirebaseAuth());
      await service.setStayLoggedIn(false);
      expect(await service.getStayLoggedIn(), isFalse);
    });

    test('persists true after being toggled', () async {
      final service = AuthService(auth: MockFirebaseAuth());
      await service.setStayLoggedIn(false);
      await service.setStayLoggedIn(true);
      expect(await service.getStayLoggedIn(), isTrue);
    });
  });
}
