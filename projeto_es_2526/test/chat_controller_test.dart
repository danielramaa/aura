import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/controllers/chat_controller.dart';
import 'package:projeto_es_2526/models/anonymous_identity.dart';
import 'package:projeto_es_2526/models/message.dart';
import 'package:projeto_es_2526/models/user_role.dart';
import 'package:projeto_es_2526/services/identity_service.dart';

Future<void> seedGroup(FakeFirebaseFirestore firestore, String groupId) =>
    firestore.collection('groups').doc(groupId).set({
      'name': groupId,
      'description': '',
      'memberCount': 0,
      'color': 0xFF000000,
    });

ChatController makeController(
  FakeFirebaseFirestore firestore,
  MockFirebaseAuth auth, {
  String groupId = 'g1',
}) {
  return ChatController(
    groupId: groupId,
    firestore: firestore,
    auth: auth,
    identityService: IdentityService(firestore: firestore),
  );
}

Future<void> waitForInit(ChatController controller) async {
  while (controller.isLoading) {
    await Future.delayed(Duration.zero);
  }
}

void main() {
  group('ChatController', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late ChatController controller;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'g1');
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-1'),
      );
      controller = makeController(firestore, auth);
      await waitForInit(controller);
    });

    tearDown(() => controller.dispose());

    test('maxMessageLength is 2000', () {
      expect(ChatController.maxMessageLength, equals(2000));
    });

    test('ignores empty or whitespace-only text', () async {
      await controller.send('   ', senderRole: UserRole.user);
      final snap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .get();
      expect(snap.docs, isEmpty);
      expect(controller.error, isNull);
    });

    test('trims whitespace before sending', () async {
      await controller.send('  hello  ', senderRole: UserRole.user);
      final snap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['text'], 'hello');
    });

    test(
      'sets error and does not send when text exceeds maxMessageLength',
      () async {
        final longText = 'a' * (ChatController.maxMessageLength + 1);
        await controller.send(longText, senderRole: UserRole.user);
        final snap = await firestore
            .collection('groups')
            .doc('g1')
            .collection('messages')
            .get();
        expect(snap.docs, isEmpty);
        expect(controller.error, isNotNull);
      },
    );

    test('clears error after valid send following an error', () async {
      await controller.send(
        'a' * (ChatController.maxMessageLength + 1),
        senderRole: UserRole.user,
      );
      expect(controller.error, isNotNull);
      await controller.send('valid message', senderRole: UserRole.user);
      expect(controller.error, isNull);
    });

    test('isSending is true during send and false after', () async {
      final states = <bool>[];
      controller.addListener(() => states.add(controller.isSending));
      await controller.send('hello', senderRole: UserRole.user);
      expect(states, containsAllInOrder([true, false]));
    });

    test('concurrent send is blocked while isSending', () async {
      final first = controller.send('first', senderRole: UserRole.user);
      expect(controller.isSending, isTrue);

      await controller.send('second', senderRole: UserRole.user);
      await first;

      final snap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['text'], 'first');
    });

    test('messages stream is reflected in controller', () async {
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .add({
            'text': 'stream message',
            'senderId': 'anon-external',
            'senderNickname': 'BraveOwl7',
            'timestamp': Timestamp.now(),
            'replyToText': null,
          });
      await Future.microtask(() {});
      expect(
        controller.messages.any((m) => m.text == 'stream message'),
        isTrue,
      );
      expect(controller.isLoading, isFalse);
    });
  });

  group('ChatController — typing indicator', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late ChatController controller;

    CollectionReference<Map<String, dynamic>> typingRef(
      FakeFirebaseFirestore fs,
    ) => fs.collection('groups').doc('g1').collection('typing');

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'g1');
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-1'),
      );
      controller = makeController(firestore, auth);
      await waitForInit(controller);
    });

    tearDown(() => controller.dispose());

    test('notifyTyping does nothing before identity is loaded', () async {
      final earlyController = makeController(firestore, auth);
      earlyController.notifyTyping();
      final snap = await typingRef(firestore).get();
      expect(snap.docs, isEmpty);
      earlyController.dispose();
    });

    test('notifyTyping writes typing doc on first call', () async {
      controller.notifyTyping();
      await Future.delayed(Duration.zero);
      final snap = await typingRef(firestore).get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['nickname'], isNotNull);
    });

    test('notifyTyping does not write again on subsequent calls', () async {
      controller.notifyTyping();
      controller.notifyTyping();
      controller.notifyTyping();
      await Future.delayed(Duration.zero);
      final snap = await typingRef(firestore).get();
      expect(snap.docs.length, 1);
    });

    test('send clears typing doc', () async {
      controller.notifyTyping();
      await Future.delayed(Duration.zero);
      expect((await typingRef(firestore).get()).docs, isNotEmpty);

      await controller.send('hello', senderRole: UserRole.user);
      await Future.delayed(Duration.zero);
      expect((await typingRef(firestore).get()).docs, isEmpty);
    });

    test('dispose clears typing doc', () async {
      final c = makeController(firestore, auth);
      await waitForInit(c);

      c.notifyTyping();
      await Future.delayed(Duration.zero);
      expect((await typingRef(firestore).get()).docs, isNotEmpty);

      c.dispose();
      await Future.delayed(Duration.zero);
      expect((await typingRef(firestore).get()).docs, isEmpty);
    });
  });

  group('ChatController — @mentions', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late ChatController controller;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'g1');
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('takenNicknames')
          .doc('Alice')
          .set({});
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('takenNicknames')
          .doc('Bob')
          .set({});
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-1'),
      );
      controller = makeController(firestore, auth);
      await waitForInit(controller);
    });

    tearDown(() => controller.dispose());

    Future<List<String>> mentionsOf(String text) async {
      await controller.send(text, senderRole: UserRole.user);
      final snap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .get();
      return List<String>.from(snap.docs.last.data()['mentions'] ?? []);
    }

    test('extracts a valid mention at the start of a message', () async {
      expect(await mentionsOf('@Alice hello'), ['Alice']);
    });

    test('extracts a valid mention at the end of a message', () async {
      expect(await mentionsOf('hey @Bob'), ['Bob']);
    });

    test('ignores unknown nicknames', () async {
      expect(await mentionsOf('hello @Nobody'), isEmpty);
    });

    test('no @-token produces empty mentions', () async {
      expect(await mentionsOf('plain text'), isEmpty);
    });

    test('extracts multiple valid mentions', () async {
      final mentions = await mentionsOf('@Alice and @Bob');
      expect(mentions, containsAll(['Alice', 'Bob']));
      expect(mentions.length, 2);
    });

    test('does not include own nickname in roomNicknames', () {
      final own = controller.anonymousIdentity?.nickname;
      expect(controller.roomNicknames, isNot(contains(own)));
    });

    test('refreshRoomNicknames picks up a newly added member', () async {
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('takenNicknames')
          .doc('Charlie')
          .set({});
      await controller.refreshRoomNicknames();
      expect(controller.roomNicknames, contains('Charlie'));
    });
  });

  group('ChatController — reactions', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late ChatController controller;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'g1');
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-1'),
      );
      controller = makeController(firestore, auth);
      await waitForInit(controller);

      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hello',
            'senderId': controller.anonymousIdentity!.anonymousId,
            'senderNickname': controller.anonymousIdentity!.nickname,
            'timestamp': Timestamp.now(),
            'reactions': {},
          });
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
    });

    tearDown(() => controller.dispose());

    test('toggleReaction returns early when message is not in list', () async {
      await controller.toggleReaction('nonexistent-id', '👍');
      expect(controller.hasReactionError('nonexistent-id'), isFalse);
    });

    test('hasReactionError is false initially', () {
      expect(controller.hasReactionError('m1'), isFalse);
    });

    test('retryReaction does nothing when there is no error', () async {
      await controller.retryReaction('m1');
      expect(controller.hasReactionError('m1'), isFalse);
    });

    test('isRetryingReaction is false initially', () {
      expect(controller.isRetryingReaction('m1'), isFalse);
    });
  });

  group('ChatController — user reports', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late ChatController controller;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'g1');
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-1'),
      );
      controller = makeController(firestore, auth);
      await waitForInit(controller);
    });

    tearDown(() => controller.dispose());

    test('creates a report for another anonymous user', () async {
      final message = Message(
        id: 'm1',
        text: 'bad message',
        anonymousId: 'anon-reported',
        senderNickname: 'BraveOwl7',
        senderAvatarIndex: 2,
        timestamp: Timestamp.now(),
      );

      final err = await controller.reportUser(
        reportedMessage: message,
        category: 'Abuse',
        reason: 'Insultos repetidos',
        description: 'Repeated insults.',
      );

      expect(err, isNull);
      final reports = await firestore.collection('user_reports').get();
      expect(reports.docs.length, 1);
      expect(reports.docs.first.data()['reportedNickname'], 'BraveOwl7');
      expect(reports.docs.first.data()['groupName'], 'g1');
    });

    test('creates a report for a message', () async {
      final message = Message(
        id: 'm1',
        text: 'mensagem imprópria',
        anonymousId: 'anon-author',
        senderNickname: 'BraveOwl7',
        senderAvatarIndex: 2,
        timestamp: Timestamp.now(),
      );

      final err = await controller.reportMessage(
        message: message,
        category: 'Misinformation',
        details: 'Informação falsa sobre saúde.',
      );

      expect(err, isNull);
      final reports = await firestore.collection('message_reports').get();
      expect(reports.docs.length, 1);
      expect(reports.docs.first.data()['messageId'], 'm1');
      expect(reports.docs.first.data()['messageText'], 'mensagem imprópria');
      expect(reports.docs.first.data()['messageSenderNickname'], 'BraveOwl7');
      expect(reports.docs.first.data()['groupName'], 'g1');
    });
  });

  group('AnonymousIdentity.fromMap', () {
    test('parses a complete map', () {
      final identity = AnonymousIdentity.fromMap({
        'anonymousId': 'anon-123',
        'nickname': 'CalmWolf42',
        'avatarIndex': 7,
      });
      expect(identity.anonymousId, 'anon-123');
      expect(identity.nickname, 'CalmWolf42');
      expect(identity.avatarIndex, 7);
    });

    test('uses fallbacks for missing fields', () {
      final identity = AnonymousIdentity.fromMap({});
      expect(identity.anonymousId, '');
      expect(identity.nickname, 'Anonymous');
      expect(identity.avatarIndex, 0);
    });

    test('toMap round-trips through fromMap', () {
      final original = AnonymousIdentity(
        anonymousId: 'id1',
        nickname: 'BraveOwl7',
        avatarIndex: 3,
      );
      final copy = AnonymousIdentity.fromMap(original.toMap());
      expect(copy.anonymousId, original.anonymousId);
      expect(copy.nickname, original.nickname);
      expect(copy.avatarIndex, original.avatarIndex);
    });
  });

  group('Message', () {
    test('stores all fields', () {
      final ts = Timestamp.fromDate(DateTime(2025));
      final msg = Message(
        id: '1',
        text: 'hello',
        anonymousId: 'anon-1',
        senderNickname: 'CalmWolf42',
        senderAvatarIndex: 0,
        timestamp: ts,
        replyToText: 'original',
      );
      expect(msg.id, '1');
      expect(msg.text, 'hello');
      expect(msg.anonymousId, 'anon-1');
      expect(msg.senderNickname, 'CalmWolf42');
      expect(msg.timestamp, ts);
      expect(msg.replyToText, 'original');
    });

    test('replyToText defaults to null', () {
      final msg = Message(
        id: '2',
        text: 'hi',
        anonymousId: 'anon-2',
        senderNickname: 'BraveOwl7',
        senderAvatarIndex: 0,
        timestamp: Timestamp.now(),
      );
      expect(msg.replyToText, isNull);
    });
  });

  group('ChatController — deleteMessage', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
    });

    test('removes the message from Firestore', () async {
      await seedGroup(firestore, 'g1');
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hello',
            'senderId': 'anon-1',
            'timestamp': Timestamp.now(),
          });

      final controller = makeController(firestore, auth);
      await waitForInit(controller);

      await controller.deleteMessage('m1');

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      expect(doc.exists, isFalse);

      controller.dispose();
    });
  });

  group('ChatController — pinned messages', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late ChatController controller;

    CollectionReference<Map<String, dynamic>> pinnedRef(
      FakeFirebaseFirestore fs,
    ) => fs.collection('groups').doc('g1').collection('pinnedMessages');

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await seedGroup(firestore, 'g1');
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-1'),
      );
      controller = makeController(firestore, auth);
      await waitForInit(controller);
    });

    tearDown(() => controller.dispose());

    Message makeMessage(String id) => Message(
      id: id,
      text: 'pin me',
      anonymousId: controller.anonymousIdentity!.anonymousId,
      senderNickname: controller.anonymousIdentity!.nickname,
      senderAvatarIndex: 0,
      timestamp: Timestamp.now(),
    );

    test('pinned stream is reflected in controller state', () async {
      expect(controller.isMessagePinned('m1'), isFalse);

      await pinnedRef(firestore).doc('m1').set({
        'text': 'pin me',
        'senderNickname': 'BraveOwl7',
        'senderAvatarIndex': 0,
        'timestamp': Timestamp.now(),
        'pinnedAt': Timestamp.now(),
      });
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect(controller.isMessagePinned('m1'), isTrue);
      expect(controller.pinnedMessages.any((p) => p.messageId == 'm1'), isTrue);
    });

    test('pinMessage writes to Firestore and updates state', () async {
      await controller.pinMessage(makeMessage('m1'));
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect((await pinnedRef(firestore).doc('m1').get()).exists, isTrue);
      expect(controller.isMessagePinned('m1'), isTrue);
      expect(controller.error, isNull);
    });

    test('unpinMessage removes from Firestore and updates state', () async {
      await controller.pinMessage(makeMessage('m1'));
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);
      expect(controller.isMessagePinned('m1'), isTrue);

      await controller.unpinMessage('m1');
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      expect((await pinnedRef(firestore).doc('m1').get()).exists, isFalse);
      expect(controller.isMessagePinned('m1'), isFalse);
      expect(controller.error, isNull);
    });
  });
}
