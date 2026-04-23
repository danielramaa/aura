import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/controllers/chat_controller.dart';
import 'package:projeto_es_2526/models/anonymous_identity.dart';
import 'package:projeto_es_2526/models/message.dart';
import 'package:projeto_es_2526/services/identity_service.dart';

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
      auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'user-1'));
      controller = makeController(firestore, auth);
      await waitForInit(controller);
    });

    tearDown(() => controller.dispose());

    test('maxMessageLength is 2000', () {
      expect(ChatController.maxMessageLength, equals(2000));
    });

    test('ignores empty or whitespace-only text', () async {
      await controller.send('   ');
      final snap = await firestore.collection('groups').doc('g1').collection('messages').get();
      expect(snap.docs, isEmpty);
      expect(controller.error, isNull);
    });

    test('trims whitespace before sending', () async {
      await controller.send('  hello  ');
      final snap = await firestore.collection('groups').doc('g1').collection('messages').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['text'], 'hello');
    });

    test('sets error and does not send when text exceeds maxMessageLength', () async {
      final longText = 'a' * (ChatController.maxMessageLength + 1);
      await controller.send(longText);
      final snap = await firestore.collection('groups').doc('g1').collection('messages').get();
      expect(snap.docs, isEmpty);
      expect(controller.error, isNotNull);
    });

    test('clears error after valid send following an error', () async {
      await controller.send('a' * (ChatController.maxMessageLength + 1));
      expect(controller.error, isNotNull);
      await controller.send('valid message');
      expect(controller.error, isNull);
    });

    test('isSending is true during send and false after', () async {
      final states = <bool>[];
      controller.addListener(() => states.add(controller.isSending));
      await controller.send('hello');
      expect(states, containsAllInOrder([true, false]));
    });

    test('concurrent send is blocked while isSending', () async {
      final first = controller.send('first');
      expect(controller.isSending, isTrue);

      await controller.send('second'); // blocked — isSending is true
      await first;

      final snap = await firestore.collection('groups').doc('g1').collection('messages').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['text'], 'first');
    });

    test('messages stream is reflected in controller', () async {
      await firestore.collection('groups').doc('g1').collection('messages').add({
        'text': 'stream message',
        'senderId': 'anon-external',
        'senderNickname': 'BraveOwl7',
        'timestamp': Timestamp.now(),
        'replyToText': null,
      });
      await Future.microtask(() {});
      expect(controller.messages.any((m) => m.text == 'stream message'), isTrue);
      expect(controller.isLoading, isFalse);
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
      final copy = AnonymousIdentity.fromMap(original.toMap());
      expect(copy.anonymousId, original.anonymousId);
      expect(copy.nickname, original.nickname);
      expect(copy.avatarUrl, original.avatarUrl);
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
        timestamp: Timestamp.now(),
      );
      expect(msg.replyToText, isNull);
    });
  });
}
