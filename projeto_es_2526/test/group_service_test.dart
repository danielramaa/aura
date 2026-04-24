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
      });
      await firestore.collection('groups').doc('g-a').set({
        'name': 'Alpha',
        'description': 'A',
        'memberCount': 1,
        'color': 0xFF000000,
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
      });

      final service = GroupService(firestore: firestore);
      final group = (await service.streamGroups().first).first;

      expect(group.id, 'g1');
      expect(group.name, 'Test');
      expect(group.description, 'A group');
      expect(group.memberCount, 42);
      expect(group.color.toARGB32(), 0xFFFF0000);
    });

    test('emits updates when groups change', () async {
      final firestore = FakeFirebaseFirestore();
      final service = GroupService(firestore: firestore);

      await firestore.collection('groups').doc('g1').set({
        'name': 'First',
        'description': '',
        'memberCount': 0,
        'color': 0xFF000000,
      });

      final emissions = <int>[];
      final sub =
          service.streamGroups().listen((g) => emissions.add(g.length));
      await Future.delayed(Duration.zero);

      await firestore.collection('groups').doc('g2').set({
        'name': 'Second',
        'description': '',
        'memberCount': 0,
        'color': 0xFF000000,
      });
      await Future.delayed(Duration.zero);

      await sub.cancel();
      expect(emissions, contains(1));
      expect(emissions, contains(2));
    });
  });
}
