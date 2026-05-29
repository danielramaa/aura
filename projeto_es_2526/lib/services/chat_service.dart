import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/anonymous_identity.dart';
import '../models/message.dart';
import '../models/message_search_result.dart';
import '../models/pinned_message.dart';

abstract class ChatServiceInterface {
  Stream<List<Message>> streamMessages(String groupId);
  Stream<List<PinnedMessage>> streamPinnedMessages(String groupId);

  Future<MessageSearchPage> searchMessages({
    required String groupId,
    required String query,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int pageSize = 40,
    int maxResults = 20,
  });

  Future<String?> sendMessage({
    required String groupId,
    required String text,
    required AnonymousIdentity identity,
    String? replyToText,
    List<String> mentions = const [],
    required String senderRole,
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

  Future<String?> pinMessage({
    required String groupId,
    required Message message,
  });

  Future<String?> unpinMessage({
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

  CollectionReference<Map<String, dynamic>> _pinnedRef(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('pinnedMessages');

  @override
  Stream<List<Message>> streamMessages(String groupId) => _messagesRef(groupId)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(Message.fromFirestore).toList());

  @override
  Future<MessageSearchPage> searchMessages({
    required String groupId,
    required String query,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int pageSize = 40,
    int maxResults = 20,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const MessageSearchPage(
        results: [],
        lastDocument: null,
        hasMore: false,
      );
    }

    final baseQuery = _messagesRef(
      groupId,
    ).orderBy('timestamp', descending: true);
    var firestoreQuery = baseQuery.limit(pageSize);
    if (startAfter != null) {
      firestoreQuery = firestoreQuery.startAfterDocument(startAfter);
    }

    final snap = await firestoreQuery.get();
    final results = <MessageSearchResult>[];
    DocumentSnapshot<Map<String, dynamic>>? lastScannedDocument;
    // Whether we visited every fetched doc. False means we hit maxResults with
    // unscanned docs still left in this page, which is itself a "more" signal.
    var scannedWholePage = true;

    for (var i = 0; i < snap.docs.length; i++) {
      final doc = snap.docs[i];
      lastScannedDocument = doc;
      final message = Message.fromFirestore(doc);
      if (message.type != MessageType.text) continue;

      final text = message.text;
      final matchStart = text.toLowerCase().indexOf(normalizedQuery);
      if (matchStart == -1) continue;

      final snippetMatchStart = _snippetMatchStart(text, matchStart);
      results.add(
        MessageSearchResult(
          message: message,
          query: query.trim(),
          snippet: _buildSearchSnippet(
            text,
            matchStart,
            normalizedQuery.length,
          ),
          matchStart: snippetMatchStart,
          matchEnd: snippetMatchStart + normalizedQuery.length,
          snapshot: doc,
        ),
      );

      if (results.length >= maxResults) {
        scannedWholePage = i == snap.docs.length - 1;
        break;
      }
    }

    return MessageSearchPage(
      results: results,
      lastDocument: lastScannedDocument ?? startAfter,
      // More may remain either because docs in this page went unscanned, or
      // because Firestore returned a full page that could be followed by more.
      hasMore: !scannedWholePage || snap.docs.length == pageSize,
    );
  }

  int _snippetMatchStart(String text, int matchStart) {
    const contextLength = 35;
    final start = math.max(0, matchStart - contextLength);
    final prefixLength = start > 0 ? 3 : 0;
    return prefixLength + matchStart - start;
  }

  String _buildSearchSnippet(String text, int matchStart, int queryLength) {
    const contextLength = 35;
    final start = math.max(0, matchStart - contextLength);
    final end = math.min(text.length, matchStart + queryLength + contextLength);
    final prefix = start > 0 ? '...' : '';
    final suffix = end < text.length ? '...' : '';
    return '$prefix${text.substring(start, end)}$suffix';
  }

  @override
  Stream<List<PinnedMessage>> streamPinnedMessages(String groupId) =>
      _pinnedRef(groupId)
          .orderBy('pinnedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(PinnedMessage.fromFirestore).toList());

  @override
  Future<String?> sendMessage({
    required String groupId,
    required String text,
    required AnonymousIdentity identity,
    String? replyToText,
    List<String> mentions = const [],
    required String senderRole,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'A mensagem não pode estar vazia.';
    if (trimmed.length > maxMessageLength) {
      return 'A mensagem não pode exceder $maxMessageLength caracteres.';
    }

    try {
      await _messagesRef(groupId).add({
        'text': trimmed,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': identity.anonymousId,
        'senderNickname': identity.nickname,
        'senderAvatarIndex': identity.avatarIndex,
        'replyToText': replyToText,
        'senderRole': senderRole,
        'mentions': mentions,
        'reactions': {},
      });
      return null;
    } catch (_) {
      return 'Falha ao enviar a mensagem. Tente novamente.';
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
        if (!snap.exists) throw Exception('Mensagem não encontrada.');

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
      return 'Não foi possível adicionar a reação. Por favor tente novamente.';
    }
  }

  @override
  Future<String?> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    try {
      // Delete the message and any pinned entry for it atomically. The pinned
      // doc shares the message id, so deleting it unconditionally is a no-op
      // when the message wasn't pinned and prevents orphan pinned banners.
      final batch = _firestore.batch();
      batch.delete(_messagesRef(groupId).doc(messageId));
      batch.delete(_pinnedRef(groupId).doc(messageId));
      await batch.commit();
      return null;
    } catch (_) {
      return 'Não foi possível eliminar a mensagem. Por favor, tente novamente.';
    }
  }

  @override
  Future<String?> pinMessage({
    required String groupId,
    required Message message,
  }) async {
    try {
      await _pinnedRef(groupId).doc(message.id).set({
        'text': message.text,
        'senderNickname': message.senderNickname,
        'senderAvatarIndex': message.senderAvatarIndex,
        'timestamp': message.timestamp,
        'pinnedAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (_) {
      return 'Failed to pin message. Please try again.';
    }
  }

  @override
  Future<String?> unpinMessage({
    required String groupId,
    required String messageId,
  }) async {
    try {
      await _pinnedRef(groupId).doc(messageId).delete();
      return null;
    } catch (_) {
      return 'Failed to unpin message. Please try again.';
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
        if (!snap.exists) throw Exception('Mensagem não encontrada.');

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
