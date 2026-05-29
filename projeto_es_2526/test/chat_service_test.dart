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

  group('ChatService — searchMessages', () {
    late FakeFirebaseFirestore firestore;
    late ChatService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = ChatService(firestore: firestore);
    });

    CollectionReference<Map<String, dynamic>> messagesRef() =>
        firestore.collection('groups').doc('g1').collection('messages');

    // Seeds a text message. [second] makes the timestamp deterministic so the
    // descending-by-timestamp scan order is predictable.
    Future<void> seedText(String text, {required int second}) =>
        messagesRef().add({
          'text': text,
          'senderId': 'anon-1',
          'senderNickname': 'CalmWolf42',
          'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1, 0, 0, second)),
        });

    test(
      'matches case-insensitively and preserves original case in snippet',
      () async {
        await seedText('Hello World', second: 1);

        final page = await service.searchMessages(
          groupId: 'g1',
          query: 'WORLD',
        );

        expect(page.results.length, 1);
        final result = page.results.first;
        expect(result.snippet, 'Hello World');
        expect(
          result.snippet.substring(result.matchStart, result.matchEnd),
          'World',
        );
      },
    );

    test('returns no results when nothing matches', () async {
      await seedText('Hello World', second: 1);

      final page = await service.searchMessages(groupId: 'g1', query: 'absent');

      expect(page.results, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test(
      'returns empty page for a blank query without touching Firestore',
      () async {
        await seedText('Hello World', second: 1);

        final page = await service.searchMessages(groupId: 'g1', query: '   ');

        expect(page.results, isEmpty);
        expect(page.hasMore, isFalse);
        expect(page.lastDocument, isNull);
      },
    );

    test('snippet truncation offsets still bracket the match', () async {
      final text = '${'a' * 50}NEEDLE${'b' * 50}';
      await seedText(text, second: 1);

      final page = await service.searchMessages(groupId: 'g1', query: 'needle');

      final result = page.results.single;
      // Long message → snippet is windowed with ellipses on both sides.
      expect(result.snippet.startsWith('...'), isTrue);
      expect(result.snippet.endsWith('...'), isTrue);
      expect(
        result.snippet.substring(result.matchStart, result.matchEnd),
        'NEEDLE',
      );
    });

    test('skips non-text (poll) messages', () async {
      await messagesRef().add({
        'text': 'poll about pizza',
        'senderId': 'anon-1',
        'senderNickname': 'CalmWolf42',
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1, 0, 0, 1)),
        'type': 'poll',
        'pollId': 'p1',
      });

      final page = await service.searchMessages(groupId: 'g1', query: 'pizza');

      expect(page.results, isEmpty);
    });

    test('a full fetched page signals hasMore', () async {
      for (var i = 0; i < 5; i++) {
        await seedText('match $i', second: i);
      }

      final page = await service.searchMessages(
        groupId: 'g1',
        query: 'match',
        pageSize: 5,
        maxResults: 20,
      );

      expect(page.results.length, 5);
      expect(page.hasMore, isTrue);
    });

    test(
      'dense matches hitting maxResults on a short page remain reachable via '
      'load-more (regression)',
      () async {
        // 6 matching messages, fewer than pageSize. Hitting maxResults must
        // still flag hasMore so the remaining matches can be paged in.
        for (var i = 0; i < 6; i++) {
          await seedText('term $i', second: i);
        }

        final first = await service.searchMessages(
          groupId: 'g1',
          query: 'term',
          pageSize: 10,
          maxResults: 4,
        );

        expect(first.results.length, 4);
        expect(first.hasMore, isTrue);

        final second = await service.searchMessages(
          groupId: 'g1',
          query: 'term',
          pageSize: 10,
          maxResults: 4,
          startAfter: first.lastDocument,
        );

        expect(second.results.length, 2);
        expect(second.hasMore, isFalse);

        // All six matches are covered exactly once across the two pages.
        final ids = [
          ...first.results.map((r) => r.message.id),
          ...second.results.map((r) => r.message.id),
        ];
        expect(ids.toSet().length, 6);
      },
    );
  });
}
