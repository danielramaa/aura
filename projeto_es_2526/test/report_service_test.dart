import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/anonymous_identity.dart';
import 'package:projeto_es_2526/services/report_service.dart';

AnonymousIdentity makeReporter() => AnonymousIdentity(
  anonymousId: 'anon-reporter',
  nickname: 'CalmWolf42',
  avatarIndex: 0,
);

void main() {
  group('ReportService.submitUserReport', () {
    late FakeFirebaseFirestore firestore;
    late ReportService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ReportService(firestore: firestore);
    });

    test('creates a pending report', () async {
      final err = await service.submitUserReport(
        groupId: 'g1',
        groupName: 'Anxiety Support',
        reporterIdentity: makeReporter(),
        reportedAnonymousId: 'anon-reported',
        reportedNickname: 'BraveOwl7',
        reportedAvatarIndex: 3,
        category: 'Harassment',
        reason: 'Comentários inapropriados repetidos',
        description: 'Sent inappropriate comments.',
      );

      expect(err, isNull);

      final reports = await firestore.collection('user_reports').get();
      expect(reports.docs.length, 1);
      expect(reports.docs.first.data()['status'], 'pending');
      expect(reports.docs.first.data()['category'], 'Harassment');
      expect(
        reports.docs.first.data()['reason'],
        'Comentários inapropriados repetidos',
      );
      expect(reports.docs.first.data()['reportedAnonymousId'], 'anon-reported');
      expect(reports.docs.first.data()['reporterAnonymousId'], 'anon-reporter');
      expect(reports.docs.first.data().containsKey('reporterUserId'), isFalse);
    });

    test('does not allow reporting yourself', () async {
      final err = await service.submitUserReport(
        groupId: 'g1',
        groupName: 'Community',
        reporterIdentity: makeReporter(),
        reportedAnonymousId: 'anon-reporter',
        reportedNickname: 'CalmWolf42',
        reportedAvatarIndex: 0,
        category: 'Spam',
        reason: 'Spam links',
        description: '',
      );

      expect(err, contains('próprio'));
      expect((await firestore.collection('user_reports').get()).docs, isEmpty);
    });

    test('rejects unknown categories', () async {
      final err = await service.submitUserReport(
        groupId: 'g1',
        groupName: 'Community',
        reporterIdentity: makeReporter(),
        reportedAnonymousId: 'anon-reported',
        reportedNickname: 'BraveOwl7',
        reportedAvatarIndex: 3,
        category: 'Mau ambiente',
        reason: 'Bad behavior',
        description: '',
      );

      expect(err, contains('categoria válida'));
    });

    test('requires a written reason', () async {
      final err = await service.submitUserReport(
        groupId: 'g1',
        groupName: 'Community',
        reporterIdentity: makeReporter(),
        reportedAnonymousId: 'anon-reported',
        reportedNickname: 'BraveOwl7',
        reportedAvatarIndex: 3,
        category: 'Abuse',
        reason: '   ',
        description: '',
      );

      expect(err, contains('motivo'));
    });
  });

  group('ReportService.submitMessageReport', () {
    late FakeFirebaseFirestore firestore;
    late ReportService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ReportService(firestore: firestore);
    });

    test('creates a pending message report and admin notification', () async {
      final err = await service.submitMessageReport(
        groupId: 'g1',
        groupName: 'Apoio',
        reporterIdentity: makeReporter(),
        messageId: 'm1',
        messageText: 'conteúdo problemático',
        messageSenderAnonymousId: 'anon-author',
        messageSenderNickname: 'BraveOwl7',
        messageSenderAvatarIndex: 2,
        category: 'Bullying',
        details: 'A mensagem atacava outro utilizador.',
      );

      expect(err, isNull);

      final reports = await firestore.collection('message_reports').get();
      expect(reports.docs.length, 1);
      expect(reports.docs.first.data()['status'], 'pending');
      expect(reports.docs.first.data()['category'], 'Bullying');
      expect(reports.docs.first.data()['messageId'], 'm1');
      expect(
        reports.docs.first.data()['messageSenderAnonymousId'],
        'anon-author',
      );
      expect(reports.docs.first.data()['reporterAnonymousId'], 'anon-reporter');
      expect(reports.docs.first.data().containsKey('reporterUserId'), isFalse);

      final notifications = await firestore
          .collection('admin_notifications')
          .get();
      expect(notifications.docs.length, 1);
      expect(notifications.docs.first.data()['type'], 'message_report');
      expect(
        notifications.docs.first.data()['reportId'],
        reports.docs.first.id,
      );
    });

    test('rejects unknown message categories', () async {
      final err = await service.submitMessageReport(
        groupId: 'g1',
        groupName: 'Apoio',
        reporterIdentity: makeReporter(),
        messageId: 'm1',
        messageText: 'conteúdo problemático',
        messageSenderAnonymousId: 'anon-author',
        messageSenderNickname: 'BraveOwl7',
        messageSenderAvatarIndex: 2,
        category: 'Perigoso',
        details: '',
      );

      expect(err, contains('categoria válida'));
      expect(
        (await firestore.collection('message_reports').get()).docs,
        isEmpty,
      );
    });

    test('suggests life risk for high-risk text', () {
      expect(
        ReportService.suggestedMessageCategory('Quero acabar com a vida'),
        'LifeRisk',
      );
    });
  });
}
