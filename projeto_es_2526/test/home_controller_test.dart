import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/controllers/home_controller.dart';
import 'package:projeto_es_2526/models/group.dart';
import 'package:projeto_es_2526/services/group_service.dart';

class _FakeGroupService implements GroupService {
  final StreamController<List<Group>> controller =
      StreamController<List<Group>>.broadcast();

  @override
  Stream<List<Group>> streamGroups() => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> waitForStream() async {
  await Future.delayed(Duration.zero);
  await Future.delayed(Duration.zero);
}

void main() {
  group('HomeController', () {
    test('starts loading with an empty group list', () {
      final service = GroupService(firestore: FakeFirebaseFirestore());
      final controller = HomeController(service: service);
      addTearDown(controller.dispose);

      expect(controller.isLoading, isTrue);
      expect(controller.groups, isEmpty);
      expect(controller.error, isNull);
    });

    test('populates groups when the stream emits', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g1').set({
        'name': 'Alpha',
        'description': 'A',
        'memberCount': 0,
        'color': 0xFF000000,
      });

      final controller =
          HomeController(service: GroupService(firestore: firestore));
      addTearDown(controller.dispose);
      await waitForStream();

      expect(controller.isLoading, isFalse);
      expect(controller.groups.length, 1);
      expect(controller.groups.first.name, 'Alpha');
    });

    test('search filter is case-insensitive and matches partial names',
        () async {
      final firestore = FakeFirebaseFirestore();
      for (final entry in [
        ('g1', 'Anxiety & Focus'),
        ('g2', 'Parenting Support'),
        ('g3', 'Meditation Circle'),
      ]) {
        await firestore.collection('groups').doc(entry.$1).set({
          'name': entry.$2,
          'description': '',
          'memberCount': 0,
          'color': 0xFF000000,
        });
      }
      final controller =
          HomeController(service: GroupService(firestore: firestore));
      addTearDown(controller.dispose);
      await waitForStream();

      controller.setSearchQuery('anxiety');
      expect(controller.groups.length, 1);
      expect(controller.groups.first.name, 'Anxiety & Focus');

      controller.setSearchQuery('MED');
      expect(controller.groups.length, 1);
      expect(controller.groups.first.name, 'Meditation Circle');

      controller.setSearchQuery('zzzz');
      expect(controller.groups, isEmpty);
    });

    test('setSearchQuery notifies listeners', () async {
      final controller =
          HomeController(service: GroupService(firestore: FakeFirebaseFirestore()));
      addTearDown(controller.dispose);

      var notified = false;
      controller.addListener(() => notified = true);
      controller.setSearchQuery('x');
      expect(notified, isTrue);
      expect(controller.searchQuery, 'x');
    });

    test('sets error when the stream fails', () async {
      final fake = _FakeGroupService();
      final controller = HomeController(service: fake);
      addTearDown(() {
        controller.dispose();
        fake.controller.close();
      });

      fake.controller.addError(Exception('boom'));
      await waitForStream();

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNotNull);
      expect(controller.groups, isEmpty);
    });

    test('groups getter returns an unmodifiable view', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g1').set({
        'name': 'A',
        'description': '',
        'memberCount': 0,
        'color': 0xFF000000,
      });
      final controller =
          HomeController(service: GroupService(firestore: firestore));
      addTearDown(controller.dispose);
      await waitForStream();

      expect(() => controller.groups.clear(), throwsUnsupportedError);
    });
  });
}
