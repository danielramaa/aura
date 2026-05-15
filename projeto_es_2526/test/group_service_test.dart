import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/services/group_service.dart';

void main() {
  group('GroupService — streamGroups', () {
    test('emits an empty list when no groups exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = GroupService(firestore: firestore);

      final groups = await service.streamGroups().first;
      expect(groups, isEmpty);
    });

    test('emits groups ordered by name', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g-b').set({
        'name': 'Beta',
        'description': 'B',
        'memberCount': 2,
        'color': 0xFF000000,
        'category': 'General',
      });
      await firestore.collection('groups').doc('g-a').set({
        'name': 'Alpha',
        'description': 'A',
        'memberCount': 1,
        'color': 0xFF000000,
        'category': 'General',
      });

      final service = GroupService(firestore: firestore);
      final groups = await service.streamGroups().first;

      expect(groups.length, 2);
      expect(groups.first.name, 'Alpha');
      expect(groups.last.name, 'Beta');
    });

    test('parses all fields correctly', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g1').set({
        'name': 'Test',
        'description': 'A group',
        'memberCount': 42,
        'color': 0xFFFF0000,
        'category': 'Mental Health',
      });

      final service = GroupService(firestore: firestore);
      final group = (await service.streamGroups().first).first;

      expect(group.id, 'g1');
      expect(group.name, 'Test');
      expect(group.description, 'A group');
      expect(group.memberCount, 42);
      expect(group.color.toARGB32(), 0xFFFF0000);
      expect(group.category, 'Mental Health');
    });

    test('defaults category to General when field is absent', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g1').set({
        'name': 'No Category',
        'description': 'desc',
        'memberCount': 0,
        'color': 0xFF000000,
      });

      final service = GroupService(firestore: firestore);
      final group = (await service.streamGroups().first).first;

      expect(group.category, 'General');
    });

    test('emits updates when groups change', () async {
      final firestore = FakeFirebaseFirestore();
      final service = GroupService(firestore: firestore);

      await firestore.collection('groups').doc('g1').set({
        'name': 'First',
        'description': '',
        'memberCount': 0,
        'color': 0xFF000000,
        'category': 'General',
      });

      final emissions = <int>[];
      final sub = service.streamGroups().listen((g) => emissions.add(g.length));
      await Future.delayed(Duration.zero);

      await firestore.collection('groups').doc('g2').set({
        'name': 'Second',
        'description': '',
        'memberCount': 0,
        'color': 0xFF000000,
        'category': 'General',
      });
      await Future.delayed(Duration.zero);

      await sub.cancel();
      expect(emissions, contains(1));
      expect(emissions, contains(2));
    });
  });

  group('GroupService — streamJoinedGroups', () {
    Future<void> addIdentity(
      FakeFirebaseFirestore firestore,
      String userId,
      String groupId,
    ) => firestore
        .collection('users')
        .doc(userId)
        .collection('anonymousIdentities')
        .doc(groupId)
        .set({
          'anonymousId': 'anon-1',
          'nickname': 'TestUser',
          'avatarIndex': 0,
        });

    test('returns seed group when no Firestore doc exists', () async {
      final firestore = FakeFirebaseFirestore();
      final service = GroupService(firestore: firestore);
      final seed = GroupService.defaultGroups[0]; // ansiedade-e-foco

      await addIdentity(firestore, 'u1', seed.id);

      final groups = await service.streamJoinedGroups('u1').first;

      expect(groups.length, 1);
      expect(groups.first.id, seed.id);
      expect(groups.first.name, seed.name);
      expect(groups.first.isEstimate, isTrue);
    });

    test('Firestore wins over seed when both exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = GroupService(firestore: firestore);
      final seed = GroupService.defaultGroups[0];

      // Seed a Firestore document with a live memberCount
      await firestore.collection('groups').doc(seed.id).set({
        'name': seed.name,
        'description': seed.description,
        'memberCount': 42,
        'color': 0xFF2196F3,
        'category': seed.category,
      });
      await addIdentity(firestore, 'u1', seed.id);

      final groups = await service.streamJoinedGroups('u1').first;

      expect(groups.length, 1);
      expect(groups.first.memberCount, 42);
      expect(groups.first.isEstimate, isFalse);
    });

    test('returns empty list when user has no joined groups', () async {
      final firestore = FakeFirebaseFirestore();
      final service = GroupService(firestore: firestore);

      final groups = await service.streamJoinedGroups('u1').first;
      expect(groups, isEmpty);
    });

    test('returns remote group when id is not a seed', () async {
      final firestore = FakeFirebaseFirestore();
      final service = GroupService(firestore: firestore);

      await firestore.collection('groups').doc('remote-group').set({
        'name': 'Remote',
        'description': 'desc',
        'memberCount': 10,
        'color': 0xFF000000,
        'category': 'General',
      });
      await addIdentity(firestore, 'u1', 'remote-group');

      final groups = await service.streamJoinedGroups('u1').first;

      expect(groups.length, 1);
      expect(groups.first.id, 'remote-group');
      expect(groups.first.memberCount, 10);
      expect(groups.first.isEstimate, isFalse);
    });

    test('results are sorted by name', () async {
      final firestore = FakeFirebaseFirestore();
      final service = GroupService(firestore: firestore);

      // Two seed groups joined
      await addIdentity(firestore, 'u1', GroupService.defaultGroups[0].id);
      await addIdentity(firestore, 'u1', GroupService.defaultGroups[1].id);

      final groups = await service.streamJoinedGroups('u1').first;

      expect(groups.length, 2);
      final names = groups.map((g) => g.name).toList();
      expect(names, equals([...names]..sort()));
    });
  });

  group('GroupService — defaultGroups', () {
    test('contains exactly 3 seed groups', () {
      expect(GroupService.defaultGroups.length, 3);
    });

    test('all seed groups have valid categories', () {
      for (final g in GroupService.defaultGroups) {
        expect(GroupService.categories, contains(g.category));
      }
    });

    test('seed group ids are unique', () {
      final ids = GroupService.defaultGroups.map((g) => g.id).toSet();
      expect(ids.length, GroupService.defaultGroups.length);
    });
  });
}
