import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/anonymous_identity.dart';
import 'package:projeto_es_2526/services/chat_service.dart';

AnonymousIdentity makeIdentity() => AnonymousIdentity(
      anonymousId: 'anon-1',
      nickname: 'CalmWolf42',
      avatarUrl: '',
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
      );
      expect(error, isNotNull);
      expect(await messages(), isEmpty);
    });

    test('returns error when text exceeds max length', () async {
      final error = await service.sendMessage(
        groupId: 'g1',
        text: 'a' * (ChatService.maxMessageLength + 1),
        identity: identity,
      );
      expect(error, isNotNull);
      expect(await messages(), isEmpty);
    });

    test('returns null and writes message on success', () async {
      final error = await service.sendMessage(
        groupId: 'g1',
        text: 'Hello world',
        identity: identity,
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
      );
      expect((await messages()).first['text'], 'trimmed');
    });

    test('writes replyToText when provided', () async {
      await service.sendMessage(
        groupId: 'g1',
        text: 'reply',
        identity: identity,
        replyToText: 'original message',
      );
      expect((await messages()).first['replyToText'], 'original message');
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
  });
}
