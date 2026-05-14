import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/group.dart';
import 'package:projeto_es_2526/models/message.dart';
import 'package:projeto_es_2526/models/user_role.dart';

void main() {
  group('Group.fromFirestore', () {
    test('parses all fields', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g1').set({
        'name': 'Dev Circle',
        'description': 'For developers',
        'memberCount': 12,
        'color': 0xFFAA00FF,
      });

      final doc = await firestore.collection('groups').doc('g1').get();
      final group = Group.fromFirestore(doc);

      expect(group.id, 'g1');
      expect(group.name, 'Dev Circle');
      expect(group.description, 'For developers');
      expect(group.memberCount, 12);
      expect(group.color.toARGB32(), 0xFFAA00FF);
    });

    test('uses default color when color is missing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g2').set({
        'name': 'Plain',
        'description': '',
        'memberCount': 0,
      });

      final doc = await firestore.collection('groups').doc('g2').get();
      final group = Group.fromFirestore(doc);
      expect(group.color.toARGB32(), 0xFF378ADD);
    });

    test('uses 0 for memberCount when missing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.collection('groups').doc('g3').set({
        'name': 'Plain',
        'description': '',
      });

      final doc = await firestore.collection('groups').doc('g3').get();
      final group = Group.fromFirestore(doc);
      expect(group.memberCount, 0);
    });
  });

  group('Message.fromFirestore', () {
    test('parses all fields', () async {
      final firestore = FakeFirebaseFirestore();
      final ts = Timestamp.fromDate(DateTime(2026, 4, 24));
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hello',
            'senderId': 'anon-1',
            'senderNickname': 'CalmWolf42',
            'timestamp': ts,
            'replyToText': 'quoted',
          });

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      final message = Message.fromFirestore(doc);

      expect(message.id, 'm1');
      expect(message.text, 'hello');
      expect(message.anonymousId, 'anon-1');
      expect(message.senderNickname, 'CalmWolf42');
      expect(message.timestamp, ts);
      expect(message.replyToText, 'quoted');
    });

    test('falls back to "Anonymous" when senderNickname is missing', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hi',
            'senderId': 'anon-1',
            'timestamp': Timestamp.now(),
          });

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      final message = Message.fromFirestore(doc);
      expect(message.senderNickname, 'Anonymous');
    });

    test('accepts "createdAt" as a fallback for timestamp', () async {
      final firestore = FakeFirebaseFirestore();
      final ts = Timestamp.fromDate(DateTime(2026));
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({'text': 'hi', 'senderId': 'anon-1', 'createdAt': ts});

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      final message = Message.fromFirestore(doc);
      expect(message.timestamp, ts);
    });

    test('replyToText is null when not provided', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hi',
            'senderId': 'anon-1',
            'timestamp': Timestamp.now(),
          });

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      final message = Message.fromFirestore(doc);
      expect(message.replyToText, isNull);
    });

    test('parses mentions array from Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': '@Alice hi',
            'senderId': 'anon-1',
            'timestamp': Timestamp.now(),
            'mentions': ['Alice'],
          });

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      final message = Message.fromFirestore(doc);
      expect(message.mentions, ['Alice']);
    });

    test('mentions defaults to empty list on legacy messages', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'no mentions here',
            'senderId': 'anon-1',
            'timestamp': Timestamp.now(),
          });

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      final message = Message.fromFirestore(doc);
      expect(message.mentions, isEmpty);
    });

    test('parses reactions map from Firestore', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hi',
            'senderId': 'anon-1',
            'timestamp': Timestamp.now(),
            'reactions': {
              '👍': ['anon-1', 'anon-2'],
              '❤️': ['anon-3'],
            },
          });

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      final message = Message.fromFirestore(doc);
      expect(message.reactions['👍'], containsAll(['anon-1', 'anon-2']));
      expect(message.reactions['❤️'], contains('anon-3'));
    });

    test('reactions defaults to empty map on legacy messages', () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .set({
            'text': 'hi',
            'senderId': 'anon-1',
            'timestamp': Timestamp.now(),
          });

      final doc = await firestore
          .collection('groups')
          .doc('g1')
          .collection('messages')
          .doc('m1')
          .get();
      final message = Message.fromFirestore(doc);
      expect(message.reactions, isEmpty);
    });
  });

  group('Message.userReaction', () {
    Message makeMessage(Map<String, List<String>> reactions) => Message(
      id: 'm1',
      text: 'hi',
      anonymousId: 'anon-1',
      senderNickname: 'Wolf',
      senderAvatarIndex: 0,
      timestamp: Timestamp.now(),
      reactions: reactions,
    );

    test('returns the emoji the user reacted with', () {
      final msg = makeMessage({
        '👍': ['anon-1'],
        '❤️': ['anon-2'],
      });
      expect(msg.userReaction('anon-1'), '👍');
      expect(msg.userReaction('anon-2'), '❤️');
    });

    test('returns null when user has no reaction', () {
      final msg = makeMessage({
        '👍': ['anon-2'],
      });
      expect(msg.userReaction('anon-1'), isNull);
    });

    test('returns null when reactions are empty', () {
      final msg = makeMessage({});
      expect(msg.userReaction('anon-1'), isNull);
    });
  });

  group('Message.reactionSummary', () {
    Message makeMessage(Map<String, List<String>> reactions) => Message(
      id: 'm1',
      text: 'hi',
      anonymousId: 'anon-1',
      senderNickname: 'Wolf',
      senderAvatarIndex: 0,
      timestamp: Timestamp.now(),
      reactions: reactions,
    );

    test('returns entries sorted by count descending', () {
      final msg = makeMessage({
        '😂': ['anon-1'],
        '👍': ['anon-1', 'anon-2', 'anon-3'],
        '❤️': ['anon-1', 'anon-2'],
      });
      final summary = msg.reactionSummary;
      expect(summary.map((e) => e.key).toList(), ['👍', '❤️', '😂']);
      expect(summary.map((e) => e.value).toList(), [3, 2, 1]);
    });

    test('excludes emojis with zero users', () {
      final msg = makeMessage({
        '👍': [],
        '❤️': ['anon-1'],
      });
      final summary = msg.reactionSummary;
      expect(summary.length, 1);
      expect(summary.first.key, '❤️');
    });

    test('returns empty list when no reactions', () {
      final msg = makeMessage({});
      expect(msg.reactionSummary, isEmpty);
    });
  });

  group('UserRole.fromString', () {
    test('parses user', () {
      expect(UserRole.fromString('user'), UserRole.user);
    });

    test('parses medic', () {
      expect(UserRole.fromString('medic'), UserRole.medic);
    });

    test('parses admin', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
    });

    test('defaults to user for null', () {
      expect(UserRole.fromString(null), UserRole.user);
    });

    test('defaults to user for unknown string', () {
      expect(UserRole.fromString('superadmin'), UserRole.user);
    });
  });

  group('UserRole.firestoreValue', () {
    test('serializes correctly', () {
      expect(UserRole.user.firestoreValue, 'user');
      expect(UserRole.medic.firestoreValue, 'medic');
      expect(UserRole.admin.firestoreValue, 'admin');
    });

    test('round-trips through fromString', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromString(role.firestoreValue), role);
      }
    });
  });
}
