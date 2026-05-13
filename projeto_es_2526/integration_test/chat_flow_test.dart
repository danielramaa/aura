import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:projeto_es_2526/controllers/chat_controller.dart';
import 'package:projeto_es_2526/services/chat_service.dart';
import 'package:projeto_es_2526/services/identity_service.dart';

Future<void> _waitForInit(ChatController controller) async {
  while (controller.isLoading) {
    await Future.delayed(Duration.zero);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Chat end-to-end flow', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'user-1'),
      );
      await firestore.collection('groups').doc('g1').set({
        'name': 'Anxiety',
        'description': 'Support group',
        'memberCount': 5,
        'color': 0xFF378ADD,
      });
    });

    test(
      'user joins, sends message, and it appears under anonymous identity only',
      () async {
        final controller = ChatController(
          groupId: 'g1',
          firestore: firestore,
          auth: auth,
          identityService: IdentityService(firestore: firestore),
        );
        await _waitForInit(controller);

        await controller.send('Hello community');

        final snap = await firestore
            .collection('groups')
            .doc('g1')
            .collection('messages')
            .get();

        expect(snap.docs.length, 1);
        final data = snap.docs.first.data();
        expect(data['text'], 'Hello community');
        expect(data['senderId'], isNotNull);
        expect(data['senderId'], isNot('user-1'));
        expect(data['senderNickname'], isNotEmpty);

        controller.dispose();
      },
    );

    test('second session reuses the same anonymous identity', () async {
      final first = ChatController(
        groupId: 'g1',
        firestore: firestore,
        auth: auth,
        identityService: IdentityService(firestore: firestore),
      );
      await _waitForInit(first);
      final firstIdentity = first.anonymousIdentity!;
      first.dispose();

      final second = ChatController(
        groupId: 'g1',
        firestore: firestore,
        auth: auth,
        identityService: IdentityService(firestore: firestore),
      );
      await _waitForInit(second);
      final secondIdentity = second.anonymousIdentity!;
      second.dispose();

      expect(secondIdentity.anonymousId, firstIdentity.anonymousId);
      expect(secondIdentity.nickname, firstIdentity.nickname);
    });

    test('reply carries replyToText on the persisted message', () async {
      final controller = ChatController(
        groupId: 'g1',
        firestore: firestore,
        auth: auth,
        identityService: IdentityService(firestore: firestore),
      );
      await _waitForInit(controller);

      await controller.send('Original message');
      await controller.send('Replying', replyToText: 'Original message');

      final snap = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .orderBy('timestamp')
          .get();

      expect(snap.docs.length, 2);
      expect(snap.docs.last.data()['replyToText'], 'Original message');

      controller.dispose();
    });

    test(
      'sending a message creates a notification in the notifications collection',
      () async {
        final controller = ChatController(
          groupId: 'g1',
          firestore: firestore,
          auth: auth,
          identityService: IdentityService(firestore: firestore),
        );
        await _waitForInit(controller);

        await controller.send('Hello');
        // notification is fire-and-forget; give it a microtask
        await Future.delayed(Duration.zero);

        final notifs = await firestore.collection('notifications').get();
        expect(notifs.docs.length, 1);
        expect(notifs.docs.first.data()['groupId'], 'g1');
        expect(notifs.docs.first.data()['groupName'], 'Anxiety');
        expect(notifs.docs.first.data()['type'], 'message');
        expect(notifs.docs.first.data()['isRead'], isFalse);

        controller.dispose();
      },
    );

    test('typing indicator is written then cleared on send', () async {
      final controller = ChatController(
        groupId: 'g1',
        firestore: firestore,
        auth: auth,
        identityService: IdentityService(firestore: firestore),
      );
      await _waitForInit(controller);

      controller.notifyTyping();
      await Future.delayed(Duration.zero);
      expect(
        (await firestore
                .collection('groups')
                .doc('g1')
                .collection('typing')
                .get())
            .docs,
        isNotEmpty,
      );

      await controller.send('Hello');
      await Future.delayed(Duration.zero);
      expect(
        (await firestore
                .collection('groups')
                .doc('g1')
                .collection('typing')
                .get())
            .docs,
        isEmpty,
      );

      controller.dispose();
    });

    test('ChatService + streamMessages round-trips written messages', () async {
      final service = ChatService(firestore: firestore);
      final controller = ChatController(
        groupId: 'g1',
        firestore: firestore,
        auth: auth,
        identityService: IdentityService(firestore: firestore),
        chatService: service,
      );
      await _waitForInit(controller);

      await controller.send('Message A');
      await controller.send('Message B');

      final stream = await service.streamMessages('g1').first;
      final texts = stream.map((m) => m.text).toSet();
      expect(texts, containsAll(['Message A', 'Message B']));

      controller.dispose();
    });

    test(
      'external writes to Firestore are reflected in controller state',
      () async {
        final controller = ChatController(
          groupId: 'g1',
          firestore: firestore,
          auth: auth,
          identityService: IdentityService(firestore: firestore),
        );
        await _waitForInit(controller);

        await firestore
            .collection('groups')
            .doc('g1')
            .collection('messages')
            .add({
              'text': 'From another user',
              'senderId': 'other-anon',
              'senderNickname': 'BraveOwl7',
              'timestamp': Timestamp.now(),
              'replyToText': null,
            });
        await Future.delayed(Duration.zero);

        expect(
          controller.messages.any((m) => m.text == 'From another user'),
          isTrue,
        );

        controller.dispose();
      },
    );
  });
}
