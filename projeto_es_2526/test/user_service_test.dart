import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/user_role.dart';
import 'package:projeto_es_2526/services/user_service.dart';

void main() {
  group('UserService.getRole', () {
    test('returns user when document does not exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.user);
    });

    test('returns user when role field is absent', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid1').set({
        'displayName': 'Alice',
      });
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.user);
    });

    test('returns medic when role is "medic"', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid1').set({'role': 'medic'});
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.medic);
    });

    test('returns admin when role is "admin"', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid1').set({'role': 'admin'});
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.admin);
    });

    test('falls back to user for unknown role string', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('uid1').set({
        'role': 'superpower',
      });
      final service = UserService(firestore: firestore);

      expect(await service.getRole('uid1'), UserRole.user);
    });
  });

  group('UserService.streamRole', () {
    test('emits user when document does not exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      expect(await service.streamRole('uid1').first, UserRole.user);
    });

    test('emits updated role when Firestore document changes', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      final roles = <UserRole>[];
      final sub = service.streamRole('uid1').listen(roles.add);

      await firestore.collection('users').doc('uid1').set({'role': 'medic'});
      await Future.delayed(Duration.zero);
      await firestore.collection('users').doc('uid1').update({'role': 'admin'});
      await Future.delayed(Duration.zero);

      await sub.cancel();

      expect(roles, contains(UserRole.medic));
      expect(roles, contains(UserRole.admin));
    });
  });

  group('UserService.streamPendingApplications', () {
    test('emits empty list when no applications exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      expect(await service.streamPendingApplications().first, isEmpty);
    });

    test('emits only pending applications', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('moderator_applications').add({
        'userId': 'u1',
        'userEmail': 'a@a.com',
        'licenseNumber': 'L1',
        'status': 'pending',
      });
      await firestore.collection('moderator_applications').add({
        'userId': 'u2',
        'userEmail': 'b@b.com',
        'licenseNumber': 'L2',
        'status': 'approved',
      });
      final service = UserService(firestore: firestore);

      final apps = await service.streamPendingApplications().first;
      expect(apps.length, 1);
      expect(apps.first.userId, 'u1');
      expect(apps.first.status, 'pending');
    });

    test('emits updated list when a new application is added', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      final results = <int>[];
      final sub = service.streamPendingApplications().listen(
        (apps) => results.add(apps.length),
      );

      await firestore.collection('moderator_applications').add({
        'userId': 'u1',
        'userEmail': 'a@a.com',
        'licenseNumber': 'L1',
        'status': 'pending',
      });
      await Future.delayed(Duration.zero);
      await sub.cancel();

      expect(results, contains(1));
    });
  });

  group('UserService.streamPendingUserReports', () {
    test('emits only pending user reports', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('user_reports').add({
        'groupId': 'g1',
        'groupName': 'Community',
        'reportedAnonymousId': 'anon-1',
        'reportedNickname': 'CalmWolf42',
        'reportedAvatarIndex': 0,
        'reporterAnonymousId': 'anon-2',
        'category': 'Spam',
        'reason': 'Keeps sending links',
        'description': '',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });
      await firestore.collection('user_reports').add({
        'groupId': 'g1',
        'groupName': 'Community',
        'reportedAnonymousId': 'anon-3',
        'reportedNickname': 'BraveOwl7',
        'reportedAvatarIndex': 1,
        'reporterAnonymousId': 'anon-2',
        'category': 'Abuse',
        'reason': 'Insults',
        'description': '',
        'status': 'reviewed',
        'createdAt': Timestamp.now(),
      });
      final service = UserService(firestore: firestore);

      final reports = await service.streamPendingUserReports().first;

      expect(reports.length, 1);
      expect(reports.first.reportedAnonymousId, 'anon-1');
      expect(reports.first.status, 'pending');
    });
  });

  group('UserService.updateUserReportStatus', () {
    test('sets report status to reviewed', () async {
      final firestore = FakeFirebaseFirestore();
      final reportRef = await firestore.collection('user_reports').add({
        'status': 'pending',
      });
      final service = UserService(firestore: firestore);

      final err = await service.updateUserReportStatus(
        reportRef.id,
        'reviewed',
      );

      expect(err, isNull);
      final report = await reportRef.get();
      expect(report.data()?['status'], 'reviewed');
    });

    test('rejects invalid report statuses', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      final err = await service.updateUserReportStatus('r1', 'pending');

      expect(err, contains('inválido'));
    });
  });

  group('UserService.streamPendingMessageReports', () {
    test('emits only pending message reports', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('message_reports').add({
        'groupId': 'g1',
        'groupName': 'Community',
        'messageId': 'm1',
        'messageText': 'texto denunciado',
        'messageSenderAnonymousId': 'anon-1',
        'messageSenderNickname': 'CalmWolf42',
        'messageSenderAvatarIndex': 0,
        'reporterAnonymousId': 'anon-2',
        'category': 'Spam',
        'details': '',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });
      await firestore.collection('message_reports').add({
        'groupId': 'g1',
        'groupName': 'Community',
        'messageId': 'm2',
        'messageText': 'texto já revisto',
        'messageSenderAnonymousId': 'anon-3',
        'messageSenderNickname': 'BraveOwl7',
        'messageSenderAvatarIndex': 1,
        'reporterAnonymousId': 'anon-2',
        'category': 'Bullying',
        'details': '',
        'status': 'reviewed',
        'createdAt': Timestamp.now(),
      });
      final service = UserService(firestore: firestore);

      final reports = await service.streamPendingMessageReports().first;

      expect(reports.length, 1);
      expect(reports.first.messageId, 'm1');
      expect(reports.first.status, 'pending');
    });
  });

  group('UserService.updateMessageReportStatus', () {
    test('sets message report status to dismissed', () async {
      final firestore = FakeFirebaseFirestore();
      final reportRef = await firestore.collection('message_reports').add({
        'status': 'pending',
      });
      final service = UserService(firestore: firestore);

      final err = await service.updateMessageReportStatus(
        reportRef.id,
        'dismissed',
      );

      expect(err, isNull);
      final report = await reportRef.get();
      expect(report.data()?['status'], 'dismissed');
    });

    test('rejects invalid message report statuses', () async {
      final firestore = FakeFirebaseFirestore();
      final service = UserService(firestore: firestore);

      final err = await service.updateMessageReportStatus('r1', 'pending');

      expect(err, contains('inválido'));
    });
  });

  group('UserService.approveApplication', () {
    test(
      'sets application status to approved and user role to medic',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('users').doc('u1').set({'role': 'user'});
        final appRef = await firestore.collection('moderator_applications').add(
          {'userId': 'u1', 'status': 'pending'},
        );
        final service = UserService(firestore: firestore);

        final err = await service.approveApplication(appRef.id, 'u1');

        expect(err, isNull);
        final app = await appRef.get();
        expect(app.data()?['status'], 'approved');
        final user = await firestore.collection('users').doc('u1').get();
        expect(user.data()?['role'], 'medic');
      },
    );
  });

  group('UserService.denyApplication', () {
    test('sets application status to denied', () async {
      final firestore = FakeFirebaseFirestore();
      final appRef = await firestore.collection('moderator_applications').add({
        'userId': 'u1',
        'status': 'pending',
      });
      final service = UserService(firestore: firestore);

      final err = await service.denyApplication(appRef.id);

      expect(err, isNull);
      final app = await appRef.get();
      expect(app.data()?['status'], 'denied');
    });
  });

  group('UserService.revokeMedicRole', () {
    test(
      'resets user role to user and deletes medicAnonymousIds entries',
      () async {
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('users').doc('u1').set({'role': 'medic'});
        await firestore
            .collection('users')
            .doc('u1')
            .collection('anonymousIdentities')
            .doc('g1')
            .set({'anonymousId': 'anon-1'});
        await firestore
            .collection('groups')
            .doc('g1')
            .collection('medicAnonymousIds')
            .doc('anon-1')
            .set({'isMedic': true});
        final service = UserService(firestore: firestore);

        final err = await service.revokeMedicRole('u1');

        expect(err, isNull);
        final user = await firestore.collection('users').doc('u1').get();
        expect(user.data()?['role'], 'user');
        final badge = await firestore
            .collection('groups')
            .doc('g1')
            .collection('medicAnonymousIds')
            .doc('anon-1')
            .get();
        expect(badge.exists, isFalse);
      },
    );

    test('handles user with no group memberships', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('users').doc('u1').set({'role': 'medic'});
      final service = UserService(firestore: firestore);

      final err = await service.revokeMedicRole('u1');

      expect(err, isNull);
      final user = await firestore.collection('users').doc('u1').get();
      expect(user.data()?['role'], 'user');
    });
  });
}
