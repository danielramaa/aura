import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/services/identity_service.dart';

Future<void> seedGroup(FakeFirebaseFirestore firestore, String groupId) =>
    firestore.collection('groups').doc(groupId).set({
      'name': groupId,
      'description': '',
      'memberCount': 0,
      'color': 0xFF000000,
    });

void main() {
  group('IdentityService — getOrCreateIdentity', () {
    test('creates a new identity when none exists', () async {
      final firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'group-1');
      final service = IdentityService(firestore: firestore);

      final identity = await service.getOrCreateIdentity('user-1', 'group-1');
      expect(identity.anonymousId, isNotEmpty);
      expect(identity.nickname, isNotEmpty);
    });

    test('persists the identity under the user document', () async {
      final firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'group-1');
      final service = IdentityService(firestore: firestore);

      await service.getOrCreateIdentity('user-1', 'group-1');

      final doc = await firestore
          .collection('users')
          .doc('user-1')
          .collection('anonymousIdentities')
          .doc('group-1')
          .get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['nickname'], isNotEmpty);
    });

    test('reuses the same identity on repeated calls', () async {
      final firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'group-1');
      final service = IdentityService(firestore: firestore);

      final first = await service.getOrCreateIdentity('user-1', 'group-1');
      final second = await service.getOrCreateIdentity('user-1', 'group-1');

      expect(first.anonymousId, second.anonymousId);
      expect(first.nickname, second.nickname);
    });

    test(
      'different groups produce different identities for same user',
      () async {
        final firestore = FakeFirebaseFirestore();
        await seedGroup(firestore, 'group-a');
        await seedGroup(firestore, 'group-b');
        final service = IdentityService(firestore: firestore);

        final a = await service.getOrCreateIdentity('user-1', 'group-a');
        final b = await service.getOrCreateIdentity('user-1', 'group-b');

        expect(a.anonymousId, isNot(b.anonymousId));
      },
    );

    test('writes a reverse lookup entry for moderation', () async {
      final firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'group-1');
      final service = IdentityService(firestore: firestore);

      final identity = await service.getOrCreateIdentity('user-1', 'group-1');

      final lookup = await firestore
          .collection('anonymousIdentities')
          .doc(identity.anonymousId)
          .get();
      expect(lookup.exists, isTrue);
      expect(lookup.data()!['userId'], 'user-1');
      expect(lookup.data()!['groupId'], 'group-1');
    });

    test('reserves the chosen nickname in the group', () async {
      final firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'group-1');
      final service = IdentityService(firestore: firestore);

      final identity = await service.getOrCreateIdentity('user-1', 'group-1');

      final reservation = await firestore
          .collection('groups')
          .doc('group-1')
          .collection('takenNicknames')
          .doc(identity.nickname)
          .get();
      expect(reservation.exists, isTrue);
    });

    test(
      'different users in the same group receive different nicknames',
      () async {
        final firestore = FakeFirebaseFirestore();
        await seedGroup(firestore, 'group-1');
        final service = IdentityService(firestore: firestore);

        final a = await service.getOrCreateIdentity('user-a', 'group-1');
        final b = await service.getOrCreateIdentity('user-b', 'group-1');

        expect(a.nickname, isNot(b.nickname));
      },
    );
  });
}
