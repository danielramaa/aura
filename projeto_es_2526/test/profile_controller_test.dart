import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/controllers/profile_controller.dart';

ProfileController makeController({
  MockFirebaseAuth? auth,
  FakeFirebaseFirestore? firestore,
}) {
  return ProfileController(
    auth:
        auth ??
        MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
        ),
    firestore: firestore ?? FakeFirebaseFirestore(),
  );
}

Future<void> waitForCommunities(ProfileController controller) async {
  while (controller.isLoadingCommunities) {
    await Future.delayed(Duration.zero);
  }
}

void main() {
  group('ProfileController — community loading', () {
    test('starts loading and clears error on init', () {
      final controller = makeController();
      addTearDown(controller.dispose);
      expect(controller.isLoadingCommunities, isTrue);
      expect(controller.communityError, isNull);
    });

    test('joinedCommunities is empty when user has no identities', () async {
      final controller = makeController();
      addTearDown(controller.dispose);
      await waitForCommunities(controller);
      expect(controller.joinedCommunities, isEmpty);
      expect(controller.communityError, isNull);
    });

    test('loads group names from anonymousIdentities', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
      );

      await firestore.collection('groups').doc('g1').set({
        'name': 'Developers',
        'description': 'Dev group',
        'memberCount': 10,
        'color': 0xFF378ADD,
      });
      await firestore
          .collection('users')
          .doc('u1')
          .collection('anonymousIdentities')
          .doc('g1')
          .set({});

      final controller = ProfileController(auth: auth, firestore: firestore);
      addTearDown(controller.dispose);
      await waitForCommunities(controller);

      expect(controller.joinedCommunities.length, 1);
      expect(controller.joinedCommunities.first.name, 'Developers');
      expect(controller.communityError, isNull);
    });

    test('does nothing when user is not logged in', () async {
      final controller = makeController(
        auth: MockFirebaseAuth(signedIn: false),
      );
      addTearDown(controller.dispose);
      await Future.delayed(Duration.zero);
      expect(controller.joinedCommunities, isEmpty);
      expect(controller.isLoadingCommunities, isFalse);
      expect(controller.communityError, isNull);
    });
  });

  group('ProfileController — updateProfile', () {
    late MockFirebaseAuth auth;
    late FakeFirebaseFirestore firestore;
    late ProfileController controller;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
      );
      controller = ProfileController(auth: auth, firestore: firestore);
      await waitForCommunities(controller);
    });

    tearDown(() => controller.dispose());

    test('returns error when not logged in', () async {
      final c = makeController(auth: MockFirebaseAuth(signedIn: false));
      addTearDown(c.dispose);
      final error = await c.updateProfile(
        displayName: 'Name',
        photoURL: '',
        email: '',
        newPassword: '',
        currentPassword: '',
      );
      expect(error, isNotNull);
    });

    test('rejects new password shorter than 8 characters', () async {
      final error = await controller.updateProfile(
        displayName: 'Name',
        photoURL: '',
        email: 'user@example.com',
        newPassword: 'short',
        currentPassword: 'current',
      );
      expect(error, contains('8 characters'));
    });

    test('requires current password when changing password', () async {
      final error = await controller.updateProfile(
        displayName: 'Name',
        photoURL: '',
        email: 'user@example.com',
        newPassword: 'newpassword123',
        currentPassword: '',
      );
      expect(error, contains('Current password'));
    });

    test('requires current password when changing email', () async {
      final error = await controller.updateProfile(
        displayName: 'Name',
        photoURL: '',
        email: 'new@example.com',
        newPassword: '',
        currentPassword: '',
      );
      expect(error, contains('Current password'));
    });

    test('returns error when re-auth needed but user has no email', () async {
      final noEmailAuth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u2'),
      );
      final c = ProfileController(auth: noEmailAuth, firestore: firestore);
      addTearDown(c.dispose);

      final error = await c.updateProfile(
        displayName: 'Name',
        photoURL: '',
        email: '',
        newPassword: 'newpassword123',
        currentPassword: 'current',
      );
      expect(error, isNotNull);
    });

    test(
      'succeeds when only display name changes (no re-auth needed)',
      () async {
        final error = await controller.updateProfile(
          displayName: 'New Name',
          photoURL: '',
          email: 'user@example.com',
          newPassword: '',
          currentPassword: '',
        );
        expect(error, isNull);
      },
    );

    test('returns null and notifies listeners on success', () async {
      var notified = false;
      controller.addListener(() => notified = true);

      final error = await controller.updateProfile(
        displayName: 'Updated',
        photoURL: '',
        email: 'user@example.com',
        newPassword: '',
        currentPassword: '',
      );

      expect(error, isNull);
      expect(notified, isTrue);
    });
  });

  group('ProfileController — logout', () {
    test('notifies listeners after sign out', () async {
      final auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'user@example.com'),
      );
      final controller = makeController(auth: auth);
      addTearDown(controller.dispose);
      await waitForCommunities(controller);

      var notified = false;
      controller.addListener(() => notified = true);

      await controller.logout();

      expect(notified, isTrue);
    });
  });
}
