import 'dart:io';
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

    test('scheduleAccountDeletion writes to users and mail collections', () async {
      // Seed user profile
      await firestore.collection('users').doc('user-123').set({
        'role': 'user',
      });

      await service.scheduleAccountDeletion('user-123', 'test@example.com');

      final userDoc = await firestore.collection('users').doc('user-123').get();
      expect(userDoc.data()?['deletionScheduled'], isTrue);
      expect(userDoc.data()?['deletionScheduledAt'], isNotNull);
      expect(userDoc.data()?['deletionDate'], isNotNull);

      final mailDocs = await firestore.collection('mail').get();
      expect(mailDocs.docs.length, 1);
      expect(mailDocs.docs.first.data()['to'], 'test@example.com');
      expect(mailDocs.docs.first.data()['message']['subject'], contains('Confirmação'));
    });

    test('cancelAccountDeletion removes fields from users doc', () async {
      // Seed user with deletion active
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
      });

      expect(await service.isAccountDeletionScheduled('user-123'), isTrue);
    });

    test('generateExportData compiles profile and anonymous identities', () async {
      // Seed user doc
      await firestore.collection('users').doc('user-123').set({
        'role': 'medic',
        'termsAccepted': true,
        'termsVersion': 'v1',
        'privacyPolicyVersion': 'v1_priv',
        'dateOfBirth': DateTime(2000, 1, 1),
      });

      // Seed subcollection
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

      final export = await service.generateExportData('user-123');

      expect(export['profile']['uid'], 'user-123');
      expect(export['profile']['email'], 'test@example.com');
      expect(export['profile']['role'], 'medic');
      expect(export['profile']['termsVersion'], 'v1');

      final list = export['anonymousIdentities'] as List;
      expect(list.length, 1);
      expect(list.first['groupId'], 'group-abc');
      expect(list.first['anonymousId'], 'anon-456');
      expect(list.first['nickname'], 'SwiftRabbit');
    });

    test('writeExportFile writes JSON locally', () async {
      final mockData = {'test': 'value'};
      final path = await service.writeExportFile('user-123', mockData);

      final file = File(path);
      expect(await file.exists(), isTrue);

      final content = await file.readAsString();
      expect(content, contains('"test": "value"'));

      // Clean up
      await file.delete();
    });
  });
}
