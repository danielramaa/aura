import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/services/gdpr_service.dart';

void main() {
  group('GDPRService Tests', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late GDPRService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-123', email: 'test@example.com', displayName: 'John Doe'),
      );
      service = GDPRService(firestore: firestore, auth: auth);
    });

    test('scheduleAccountDeletion sets deletion fields on the user doc', () async {
      await firestore.collection('users').doc('user-123').set({'role': 'user'});

      await service.scheduleAccountDeletion('user-123');

      final userDoc = await firestore.collection('users').doc('user-123').get();
      expect(userDoc.data()?['deletionScheduled'], isTrue);
      expect(userDoc.data()?['deletionScheduledAt'], isNotNull);
      expect(userDoc.data()?['deletionDate'], isNotNull);
    });

    test('cancelAccountDeletion removes fields from users doc', () async {
      await firestore.collection('users').doc('user-123').set({
        'role': 'user',
        'deletionScheduled': true,
        'deletionScheduledAt': DateTime.now(),
        'deletionDate': DateTime.now().add(const Duration(days: 30)),
      });

      await service.cancelAccountDeletion('user-123');

      final userDoc = await firestore.collection('users').doc('user-123').get();
      expect(userDoc.data()?['deletionScheduled'], isNull);
      expect(userDoc.data()?['deletionScheduledAt'], isNull);
      expect(userDoc.data()?['deletionDate'], isNull);
    });

    test('isAccountDeletionScheduled returns status correctly', () async {
      expect(await service.isAccountDeletionScheduled('user-123'), isFalse);

      await firestore.collection('users').doc('user-123').set({
        'deletionScheduled': true,
        'deletionDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      });

      expect(await service.isAccountDeletionScheduled('user-123'), isTrue);
    });

    test('getScheduledDeletionDate returns the date only when scheduled', () async {
      expect(await service.getScheduledDeletionDate('user-123'), isNull);

      final date = DateTime.now().add(const Duration(days: 30));
      await firestore.collection('users').doc('user-123').set({
        'deletionScheduled': true,
        'deletionDate': Timestamp.fromDate(date),
      });

      final result = await service.getScheduledDeletionDate('user-123');
      expect(result, isNotNull);
      expect(result!.difference(date).inSeconds.abs() < 2, isTrue);
    });

    test('generateExportData compiles profile, identities and messages', () async {
      await firestore.collection('users').doc('user-123').set({
        'role': 'medic',
        'termsAccepted': true,
        'termsVersion': 'v1',
        'privacyPolicyVersion': 'v1_priv',
        'dateOfBirth': DateTime(2000, 1, 1),
      });

      await firestore
          .collection('users')
          .doc('user-123')
          .collection('anonymousIdentities')
          .doc('group-abc')
          .set({
            'anonymousId': 'anon-456',
            'nickname': 'SwiftRabbit',
            'avatarIndex': 2,
          });

      // A message authored by this identity, plus one by someone else.
      await firestore.collection('groups').doc('group-abc').collection('messages').add({
        'senderId': 'anon-456',
        'text': 'Hello world',
        'type': 'text',
      });
      await firestore.collection('groups').doc('group-abc').collection('messages').add({
        'senderId': 'other-anon',
        'text': 'Not mine',
      });

      final export = await service.generateExportData('user-123');

      expect(export['profile']['uid'], 'user-123');
      expect(export['profile']['email'], 'test@example.com');
      expect(export['profile']['role'], 'medic');
      expect(export['profile']['termsVersion'], 'v1');

      final identities = export['anonymousIdentities'] as List;
      expect(identities.length, 1);
      expect(identities.first['anonymousId'], 'anon-456');

      final messages = export['messages'] as List;
      expect(messages.length, 1);
      expect(messages.first['text'], 'Hello world');
      expect(messages.first['groupId'], 'group-abc');
    });

    test('writeExportFile writes JSON locally', () async {
      final mockData = {'test': 'value'};
      final path = await service.writeExportFile('user-123', mockData);

      final file = File(path);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), contains('"test": "value"'));

      await file.delete();
    });

    test('executeAccountDeletion erases profile, identities and apps, and '
        'anonymizes the reverse-lookup link', () async {
      // Profile scheduled for deletion.
      await firestore.collection('users').doc('user-123').set({
        'role': 'user',
        'deletionScheduled': true,
      });
      // User-side identity record.
      await firestore
          .collection('users')
          .doc('user-123')
          .collection('anonymousIdentities')
          .doc('group-abc')
          .set({'anonymousId': 'anon-456'});
      // Reverse-lookup mapping anon-456 -> user-123.
      await firestore.collection('anonymousIdentities').doc('anon-456').set({
        'userId': 'user-123',
        'groupId': 'group-abc',
      });
      // A moderator application owned by the user.
      await firestore.collection('moderator_applications').doc('app-1').set({
        'userId': 'user-123',
        'userEmail': 'test@example.com',
        'licenseNumber': 'LIC-1',
      });

      await service.executeAccountDeletion('user-123');

      // Profile gone.
      final userDoc = await firestore.collection('users').doc('user-123').get();
      expect(userDoc.exists, isFalse);

      // User-side identity record gone.
      final idDoc = await firestore
          .collection('users')
          .doc('user-123')
          .collection('anonymousIdentities')
          .doc('group-abc')
          .get();
      expect(idDoc.exists, isFalse);

      // Reverse-lookup still exists but the userId link is severed.
      final reverse =
          await firestore.collection('anonymousIdentities').doc('anon-456').get();
      expect(reverse.exists, isTrue);
      expect(reverse.data()?['userId'], isNull);
      expect(reverse.data()?['anonymizedAt'], isNotNull);

      // Moderator application gone.
      final appDoc =
          await firestore.collection('moderator_applications').doc('app-1').get();
      expect(appDoc.exists, isFalse);
    });
  });
}
