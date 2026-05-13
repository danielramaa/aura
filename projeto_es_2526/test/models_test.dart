import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/models/group.dart';
import 'package:projeto_es_2526/models/message.dart';

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
  });
}
