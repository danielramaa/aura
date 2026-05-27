import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/anonymous_identity.dart';
import 'package:projeto_es_2526/models/message.dart';
import 'package:projeto_es_2526/services/chat_service.dart';

AnonymousIdentity makeIdentity() => AnonymousIdentity(
  anonymousId: 'anon-1',
  nickname: 'CalmWolf42',
  avatarIndex: 0,
);

void main() {
  group('ChatService — sendMessage', () {
    late FakeFirebaseFirestore firestore;
    late ChatService service;
    late AnonymousIdentity identity;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ChatService(firestore: firestore);
      identity = makeIdentity();
    });

    Future<List<Map<String, dynamic>>> messages() async {
      final snap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .get();
      return snap.docs.map((d) => d.data()).toList();
    }

    test('returns error for empty text', () async {
      final error = await service.sendMessage(
        groupId: 'g1',
        text: '   ',
        identity: identity,
        senderRole: 'user',
      );
      expect(error, isNotNull);
      expect(await messages(), isEmpty);
    });

    test('returns error when text exceeds max length', () async {
      final error = await service.sendMessage(
        groupId: 'g1',
        text: 'a' * (ChatService.maxMessageLength + 1),
        identity: identity,
        senderRole: 'user',
      );
      expect(error, isNotNull);
      expect(await messages(), isEmpty);
    });

    test('returns null and writes message on success', () async {
      final error = await service.sendMessage(
        groupId: 'g1',
        text: 'Hello world',
        identity: identity,
        senderRole: 'user',
      );
      expect(error, isNull);
      final msgs = await messages();
      expect(msgs.length, 1);
      expect(msgs.first['text'], 'Hello world');
    });

    test('writes anonymous identity fields, not real user data', () async {
      await service.sendMessage(
        groupId: 'g1',
        text: 'test',
        identity: identity,
        senderRole: 'user',
      );
      final msg = (await messages()).first;
      expect(msg['senderId'], 'anon-1');
      expect(msg['senderNickname'], 'CalmWolf42');
    });

    test('trims whitespace before writing', () async {
      await service.sendMessage(
        groupId: 'g1',
        text: '  trimmed  ',
        identity: identity,
        senderRole: 'user',
      );
      expect((await messages()).first['text'], 'trimmed');
    });

    test('writes replyToText when provided', () async {
      await service.sendMessage(
        groupId: 'g1',
        text: 'reply',
        identity: identity,
        replyToText: 'original message',
        senderRole: 'user',
      );
      expect((await messages()).first['replyToText'], 'original message');
    });

    test('persists mentions list in the stored document', () async {
      await service.sendMessage(
        groupId: 'g1',
        text: '@Alice hello',
        identity: identity,
        mentions: ['Alice'],
        senderRole: 'user',
      );
      expect((await messages()).first['mentions'], ['Alice']);
    });

    test('persists empty mentions list when none provided', () async {
      await service.sendMessage(
        groupId: 'g1',
        text: 'no mentions',
        identity: identity,
        senderRole: 'user',
      );
      expect((await messages()).first['mentions'], isEmpty);
    });
  });

  group('ChatService — streamMessages', () {
    test('emits messages from Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ChatService(firestore: firestore);

      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .add({
            'text': 'hello',
            'senderId': 'anon-1',
            'senderNickname': 'CalmWolf42',
            'timestamp': Timestamp.now(),
            'replyToText': null,
          });

      final messages = await service.streamMessages('g1').first;
      expect(messages.length, 1);
      expect(messages.first.text, 'hello');
    });

    test('emits empty list when no messages exist', () async {
      final firestore = FakeFirebaseFirestore();
      final service = ChatService(firestore: firestore);
      final messages = await service.streamMessages('g1').first;
      expect(messages, isEmpty);
    });

    test(
      'mentions round-trip through sendMessage and streamMessages',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = ChatService(firestore: firestore);
        final identity = makeIdentity();

        await service.sendMessage(
          groupId: 'g1',
          text: '@Alice and @Bob',
          identity: identity,
          mentions: ['Alice', 'Bob'],
          senderRole: 'user',
        );

        final messages = await service.streamMessages('g1').first;
        expect(messages.first.mentions, containsAll(['Alice', 'Bob']));
      },
    );
  });

  group('ChatService — addReaction (empty start)', () {
    late FakeFirebaseFirestore firestore;
    late ChatService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = ChatService(firestore: firestore);
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hello',
            'senderId': 'anon-1',
            'senderNickname': 'CalmWolf42',
            'timestamp': Timestamp.now(),
            'reactions': {},
          });
    });

    Future<Map<String, dynamic>> reactionsOf() async {
      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      return Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
    }

    test('adds a reaction', () async {
      final err = await service.addReaction(
        groupId: 'g1',
        messageId: 'm1',
        emoji: '👍',
        anonymousId: 'anon-1',
      );
      expect(err, isNull);
      expect(await reactionsOf(), containsPair('👍', contains('anon-1')));
    });

    test('returns error when message does not exist', () async {
      final err = await service.addReaction(
        groupId: 'g1',
        messageId: 'nonexistent',
        emoji: '👍',
        anonymousId: 'anon-1',
      );
      expect(err, isNotNull);
    });
  });

  group('ChatService — addReaction (existing 👍 from anon-1)', () {
    late FakeFirebaseFirestore firestore;
    late ChatService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = ChatService(firestore: firestore);
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hello',
            'senderId': 'anon-1',
            'senderNickname': 'CalmWolf42',
            'timestamp': Timestamp.now(),
            'reactions': {
              '👍': ['anon-1'],
            },
          });
    });

    Future<Map<String, dynamic>> reactionsOf() async {
      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      return Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
    }

    test('enforces one reaction per user — replaces existing emoji', () async {
      await service.addReaction(
        groupId: 'g1',
        messageId: 'm1',
        emoji: '❤️',
        anonymousId: 'anon-1',
      );

      final reactions = await reactionsOf();
      expect(reactions['❤️'], contains('anon-1'));
      expect(reactions.containsKey('👍'), isFalse);
    });

    test('multiple users can react independently', () async {
      await service.addReaction(
        groupId: 'g1',
        messageId: 'm1',
        emoji: '👍',
        anonymousId: 'anon-2',
      );

      final reactions = await reactionsOf();
      expect(
        List<String>.from(reactions['👍'] as List),
        containsAll(['anon-1', 'anon-2']),
      );
    });
  });

  group('ChatService — removeReaction (👍 from anon-1 and anon-2)', () {
    late FakeFirebaseFirestore firestore;
    late ChatService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = ChatService(firestore: firestore);
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hello',
            'senderId': 'anon-1',
            'senderNickname': 'CalmWolf42',
            'timestamp': Timestamp.now(),
            'reactions': {
              '👍': ['anon-1', 'anon-2'],
            },
          });
    });

    Future<Map<String, dynamic>> reactionsOf() async {
      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      return Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});
    }

    test('removes the reaction for the given user', () async {
      final err = await service.removeReaction(
        groupId: 'g1',
        messageId: 'm1',
        emoji: '👍',
        anonymousId: 'anon-1',
      );
      expect(err, isNull);
      final reactions = await reactionsOf();
      expect(
        List<String>.from(reactions['👍'] as List),
        isNot(contains('anon-1')),
      );
      expect(List<String>.from(reactions['👍'] as List), contains('anon-2'));
    });
  });

  group('ChatService — removeReaction (👍 from anon-2 only)', () {
    late FakeFirebaseFirestore firestore;
    late ChatService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = ChatService(firestore: firestore);
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hello',
            'senderId': 'anon-1',
            'senderNickname': 'CalmWolf42',
            'timestamp': Timestamp.now(),
            'reactions': {
              '👍': ['anon-2'],
            },
          });
    });

    test(
      'cleans up empty emoji entry after last user removes reaction',
      () async {
        await service.removeReaction(
          groupId: 'g1',
          messageId: 'm1',
          emoji: '👍',
          anonymousId: 'anon-2',
        );

        final doc = await firestore
            .collection('groups')
            .doc('g1')
            .collection('messages')
            .doc('m1')
            .get();
        final reactions = Map<String, dynamic>.from(
          doc.data()?['reactions'] ?? {},
        );
        expect(reactions.containsKey('👍'), isFalse);
      },
    );
  });

  group('ChatService — deleteMessage', () {
    late FakeFirebaseFirestore firestore;
    late ChatService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ChatService(firestore: firestore);
    });

    Future<void> seedMessage(String messageId) => firestore
        .collection('groups')
        .doc('g1')
        .collection('messages')
        .doc(messageId)
        .set({'text': 'hello', 'senderId': 'anon-1'});

    test('removes the message document', () async {
      await seedMessage('m1');

      final err = await service.deleteMessage(groupId: 'g1', messageId: 'm1');

      expect(err, isNull);
      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      expect(doc.exists, isFalse);
    });

    test('returns null when deleting a non-existent message', () async {
      final err = await service.deleteMessage(
        groupId: 'g1',
        messageId: 'no-such-message',
      );
      expect(err, isNull);
    });

    test('also removes the pinned entry so no orphan banner remains', () async {
      await seedMessage('m1');
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('pinnedMessages')
          .doc('m1')
          .set({'text': 'hello'});

      final err = await service.deleteMessage(groupId: 'g1', messageId: 'm1');

      expect(err, isNull);
      final pinned = await firestore
          .collection('groups')
          .doc('g1')
          .collection('pinnedMessages')
          .doc('m1')
          .get();
      expect(pinned.exists, isFalse);
    });
  });

  group('ChatService — pinned messages', () {
    late FakeFirebaseFirestore firestore;
    late ChatService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ChatService(firestore: firestore);
    });

    Future<DocumentSnapshot<Map<String, dynamic>>> pinnedDoc(String id) =>
        firestore
            .collection('groups')
            .doc('g1')
            .collection('pinnedMessages')
            .doc(id)
            .get();

    Message makeMessage(String id) => Message(
      id: id,
      text: 'pinned text',
      anonymousId: 'anon-1',
      senderNickname: 'CalmWolf42',
      senderAvatarIndex: 3,
      timestamp: Timestamp.fromDate(DateTime(2026, 5, 1)),
    );

    test('pinMessage writes a pinned doc keyed by the message id', () async {
      final err = await service.pinMessage(
        groupId: 'g1',
        message: makeMessage('m1'),
      );

      expect(err, isNull);
      final doc = await pinnedDoc('m1');
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['text'], 'pinned text');
      expect(data['senderNickname'], 'CalmWolf42');
      expect(data['senderAvatarIndex'], 3);
      expect(data['timestamp'], isA<Timestamp>());
      expect(data['pinnedAt'], isNotNull);
    });

    test('unpinMessage removes the pinned doc', () async {
      await service.pinMessage(groupId: 'g1', message: makeMessage('m1'));

      final err = await service.unpinMessage(groupId: 'g1', messageId: 'm1');

      expect(err, isNull);
      expect((await pinnedDoc('m1')).exists, isFalse);
    });

    test(
      'streamPinnedMessages yields docs ordered by pinnedAt descending',
      () async {
        final pinnedRef = firestore
            .collection('groups')
            .doc('g1')
            .collection('pinnedMessages');
        await pinnedRef.doc('older').set({
          'text': 'older',
          'senderNickname': 'A',
          'senderAvatarIndex': 0,
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
          'pinnedAt': Timestamp.fromDate(DateTime(2026, 5, 1)),
        });
        await pinnedRef.doc('newer').set({
          'text': 'newer',
          'senderNickname': 'B',
          'senderAvatarIndex': 2,
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 2)),
          'pinnedAt': Timestamp.fromDate(DateTime(2026, 5, 2)),
        });

        final pinned = await service.streamPinnedMessages('g1').first;

        expect(pinned.map((p) => p.messageId), ['newer', 'older']);
        expect(pinned.first.text, 'newer');
        expect(pinned.first.senderNickname, 'B');
        expect(pinned.first.senderAvatarIndex, 2);
      },
    );

    test('streamPinnedMessages emits empty list when none exist', () async {
      expect(await service.streamPinnedMessages('g1').first, isEmpty);
    });
  });
}
