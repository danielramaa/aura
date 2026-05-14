import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/anonymous_identity.dart';
import '../models/message.dart';

abstract class ChatServiceInterface {
  Stream<List<Message>> streamMessages(String groupId);

  Future<String?> sendMessage({
    required String groupId,
    required String text,
    required AnonymousIdentity identity,
    String? replyToText,
    List<String> mentions = const [],
  });

  Future<String?> addReaction({
    required String groupId,
    required String messageId,
    required String emoji,
    required String anonymousId,
  });

  Future<String?> removeReaction({
    required String groupId,
    required String messageId,
    required String emoji,
    required String anonymousId,
  });

  Future<String?> deleteMessage({
    required String groupId,
    required String messageId,
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
  Stream<List<Message>> streamMessages(String groupId) => _messagesRef(groupId)
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
        'senderAvatarIndex': identity.avatarIndex,
        'replyToText': replyToText,
        'mentions': mentions,
        'reactions': {},
      });
      return null;
    } catch (_) {
      return 'Failed to send message. Please try again.';
    }
  }

  /// Adds [emoji] reaction from [anonymousId] to a message.
  /// Enforces one reaction per user: removes any existing reaction first.
  /// Returns null on success, or an error string on failure.
  @override
  Future<String?> addReaction({
    required String groupId,
    required String messageId,
    required String emoji,
    required String anonymousId,
  }) async {
    final docRef = _messagesRef(groupId).doc(messageId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) throw Exception('Message not found.');

        final data = snap.data() ?? {};
        final raw = data['reactions'] != null
            ? Map<String, dynamic>.from(data['reactions'] as Map)
            : <String, dynamic>{};

        // Remove user from any existing reaction (one reaction per user rule)
        final updated = raw.map(
          (e, users) => MapEntry(e, List<String>.from(users as List)),
        );
        updated.forEach((e, users) => users.remove(anonymousId));

        // Add to the chosen emoji list
        updated[emoji] = (updated[emoji] ?? [])..add(anonymousId);

        // Clean up empty entries
        updated.removeWhere((_, users) => users.isEmpty);

        // Use set (not update) so the reactions field is fully replaced,
        // not deep-merged with the existing map.
        transaction.set(docRef, {...data, 'reactions': updated});
      });
      return null;
    } catch (_) {
      return 'Não foi possível adicionar a reação. Tente novamente.';
    }
  }

  @override
  Future<String?> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    try {
      await _messagesRef(groupId).doc(messageId).delete();
      return null;
    } catch (_) {
      return 'Failed to delete message. Please try again.';
    }
  }

  /// Removes [emoji] reaction from [anonymousId].
  /// Returns null on success, or an error string on failure.
  @override
  Future<String?> removeReaction({
    required String groupId,
    required String messageId,
    required String emoji,
    required String anonymousId,
  }) async {
    final docRef = _messagesRef(groupId).doc(messageId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) throw Exception('Message not found.');

        final data = snap.data() ?? {};
        final raw = data['reactions'] != null
            ? Map<String, dynamic>.from(data['reactions'] as Map)
            : <String, dynamic>{};

        final updated = raw.map(
          (e, users) => MapEntry(e, List<String>.from(users as List)),
        );
        updated[emoji]?.remove(anonymousId);
        updated.removeWhere((_, users) => users.isEmpty);

        transaction.set(docRef, {...data, 'reactions': updated});
      });
      return null;
    } catch (_) {
      return 'Não foi possível remover a reação. Tente novamente.';
    }
  }
}
