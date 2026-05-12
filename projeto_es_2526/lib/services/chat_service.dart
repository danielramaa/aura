import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/anonymous_identity.dart';
import '../models/message.dart';

abstract class ChatServiceInterface {
  Stream<List<Message>> streamMessages(String groupId);

  /// Returns null on success, or an error message on failure.
  /// [identity] must be an anonymous identity — no real user identifier
  /// is written to the messages collection.
  Future<String?> sendMessage({
    required String groupId,
    required String text,
    required AnonymousIdentity identity,
    String? replyToText,
    List<String> mentions = const [],
  });
}

class ChatService implements ChatServiceInterface {
  static const int maxMessageLength = 2000;

  final FirebaseFirestore _firestore;

  ChatService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('messages');

  @override
  Stream<List<Message>> streamMessages(String groupId) =>
      _messagesRef(groupId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(Message.fromFirestore).toList());

  @override
  Future<String?> sendMessage({
    required String groupId,
    required String text,
    required AnonymousIdentity identity,
    String? replyToText,
    List<String> mentions = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Message cannot be empty.';
    if (trimmed.length > maxMessageLength) {
      return 'Message cannot exceed $maxMessageLength characters.';
    }

    try {
      await _messagesRef(groupId).add({
        'text': trimmed,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': identity.anonymousId,
        'senderNickname': identity.nickname,
        'replyToText': replyToText,
        'mentions': mentions,
      });
      return null;
    } catch (_) {
      return 'Failed to send message. Please try again.';
    }
  }
}