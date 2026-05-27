import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/legal_document.dart';
import 'package:projeto_es_2526/models/user_role.dart';
import 'package:projeto_es_2526/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    firestore = FakeFirebaseFirestore();
  });

  group('AuthService — authentication', () {
    test('currentUser is null when not signed in', () {
      final service = AuthService(
        auth: MockFirebaseAuth(signedIn: false),
        firestore: firestore,
      );
      expect(service.currentUser, isNull);
    });

    test('currentUser returns user when signed in', () {
      final service = AuthService(
        auth: MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
        ),
        firestore: firestore,
      );
      expect(service.currentUser, isNotNull);
      expect(service.currentUser!.email, 'user@example.com');
    });

    test('login signs in with email/password', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);

      final credential = await service.login('user@example.com', 'password123');
      expect(credential.user, isNotNull);
      expect(auth.currentUser, isNotNull);
    });

    test('register creates a new account', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'new@example.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);

      final credential = await service.register(
        'new@example.com',
        'password123',
        acceptedTerms: true,
      );
      expect(credential.user, isNotNull);
      expect(auth.currentUser, isNotNull);
    });

    test('register creates users/{uid} document with role user', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'new@example.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);

      final credential = await service.register(
        'new@example.com',
        'password123',
        acceptedTerms: true,
      );

      final uid = credential.user!.uid;
      final doc = await firestore.collection('users').doc(uid).get();
      expect(doc.exists, isTrue);
      expect(UserRole.fromString(doc.data()!['role'] as String), UserRole.user);
    });

    test('logout clears the current user', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);

      expect(service.currentUser, isNotNull);
      await service.logout();
      expect(service.currentUser, isNull);
    });

    test('sendPasswordResetEmail completes without error', () async {
      final service = AuthService(
        auth: MockFirebaseAuth(),
        firestore: firestore,
      );
      await expectLater(
        service.sendPasswordResetEmail('user@example.com'),
        completes,
      );
    });

    test('authStateChanges emits user updates', () async {
      final auth = MockFirebaseAuth();
      final service = AuthService(auth: auth, firestore: firestore);
      final states = <bool>[];
      final sub = service.authStateChanges.listen(
        (user) => states.add(user != null),
      );
      await service.register('a@b.com', 'password123', acceptedTerms: true);
      await Future.delayed(Duration.zero);
      await service.logout();
      await Future.delayed(Duration.zero);
      await sub.cancel();
      expect(states, contains(true));
      expect(states, contains(false));
    });
  });

  group('AuthService — registration compliance', () {
    DateTime ageInYears(int years) {
      final today = DateTime.now();
      return DateTime(today.year - years, today.month, today.day);
    }

    test('stores acceptance timestamp and document versions when accepted',
        () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'new@example.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);

      final credential = await service.register(
        'new@example.com',
        'password123',
        acceptedTerms: true,
      );

      final data =
          (await firestore.collection('users').doc(credential.user!.uid).get())
              .data()!;
      expect(data['termsAccepted'], isTrue);
      expect(data['termsAcceptedAt'], isNotNull);
      expect(data['termsVersion'], LegalDocuments.termsVersion);
      expect(data['privacyPolicyVersion'], LegalDocuments.privacyPolicyVersion);
    });

    test('rejects registration when terms are not accepted', () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'new@example.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);

      await expectLater(
        service.register(
          'new@example.com',
          'password123',
          acceptedTerms: false,
        ),
        throwsArgumentError,
      );
      expect(auth.currentUser, isNull);
      final users = await firestore.collection('users').get();
      expect(users.docs, isEmpty);
    });

    test('stores date of birth and verification timestamp when provided',
        () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'new@example.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);
      final dob = ageInYears(20);

      final credential = await service.register(
        'new@example.com',
        'password123',
        dateOfBirth: dob,
        acceptedTerms: true,
      );

      final data =
          (await firestore.collection('users').doc(credential.user!.uid).get())
              .data()!;
      expect((data['dateOfBirth'] as Timestamp).toDate(), dob);
      expect(data['ageVerifiedAt'], isNotNull);
    });

    test('allows registration for someone exactly at the minimum age',
        () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'new@example.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);

      await expectLater(
        service.register(
          'new@example.com',
          'password123',
          dateOfBirth: ageInYears(13),
          acceptedTerms: true,
        ),
        completes,
      );
    });

    test('rejects an under-age date of birth without creating an account',
        () async {
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'new@example.com'),
      );
      final service = AuthService(auth: auth, firestore: firestore);

      await expectLater(
        service.register(
          'new@example.com',
          'password123',
          dateOfBirth: ageInYears(10),
          acceptedTerms: true,
        ),
        throwsArgumentError,
      );
      expect(auth.currentUser, isNull);
      final users = await firestore.collection('users').get();
      expect(users.docs, isEmpty);
    });
  });

  group('AuthService — stayLoggedIn preference', () {
    test('defaults to true when not set', () async {
      final service = AuthService(
        auth: MockFirebaseAuth(),
        firestore: firestore,
      );
      expect(await service.getStayLoggedIn(), isTrue);
    });

    test('persists false after being set', () async {
      final service = AuthService(
        auth: MockFirebaseAuth(),
        firestore: firestore,
      );
      await service.setStayLoggedIn(false);
      expect(await service.getStayLoggedIn(), isFalse);
    });

    test('persists true after being toggled', () async {
      final service = AuthService(
        auth: MockFirebaseAuth(),
        firestore: firestore,
      );
      await service.setStayLoggedIn(false);
      await service.setStayLoggedIn(true);
      expect(await service.getStayLoggedIn(), isTrue);
    });
  });
}
