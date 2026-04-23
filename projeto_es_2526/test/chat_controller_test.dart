import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/controllers/chat_controller.dart';
import 'package:projeto_es_2526/models/anonymous_identity.dart';
import 'package:projeto_es_2526/models/message.dart';

void main() {
  group('ChatController', () {
    test('maxMessageLength is 2000', () {
      expect(ChatController.maxMessageLength, equals(2000));
    });
  });

  group('AnonymousIdentity.fromMap', () {
    test('parses a complete map', () {
      final identity = AnonymousIdentity.fromMap({
        'anonymousId': 'anon-123',
        'nickname': 'CalmWolf42',
        'avatarUrl': 'https://example.com/avatar.png',
      });
      expect(identity.anonymousId, 'anon-123');
      expect(identity.nickname, 'CalmWolf42');
      expect(identity.avatarUrl, 'https://example.com/avatar.png');
    });

    test('uses fallbacks for missing fields', () {
      final identity = AnonymousIdentity.fromMap({});
      expect(identity.anonymousId, '');
      expect(identity.nickname, 'Anonymous');
      expect(identity.avatarUrl, '');
    });

    test('toMap round-trips through fromMap', () {
      final original = AnonymousIdentity(
        anonymousId: 'id1',
        nickname: 'BraveOwl7',
        avatarUrl: 'https://example.com/owl.png',
      );
      final roundTripped = AnonymousIdentity.fromMap(original.toMap());
      expect(roundTripped.anonymousId, original.anonymousId);
      expect(roundTripped.nickname, original.nickname);
      expect(roundTripped.avatarUrl, original.avatarUrl);
    });
  });

  group('Message', () {
    test('constructor stores all fields', () {
      final ts = Timestamp.fromDate(DateTime(2025));
      final message = Message(
        id: '1',
        text: 'hello',
        anonymousId: 'anon-1',
        senderNickname: 'CalmWolf42',
        timestamp: ts,
        replyToText: 'original',
      );
      expect(message.id, '1');
      expect(message.text, 'hello');
      expect(message.anonymousId, 'anon-1');
      expect(message.senderNickname, 'CalmWolf42');
      expect(message.timestamp, ts);
      expect(message.replyToText, 'original');
    });

    test('replyToText defaults to null', () {
      final message = Message(
        id: '2',
        text: 'hi',
        anonymousId: 'anon-2',
        senderNickname: 'BraveOwl7',
        timestamp: Timestamp.now(),
      );
      expect(message.replyToText, isNull);
    });
  });
}
