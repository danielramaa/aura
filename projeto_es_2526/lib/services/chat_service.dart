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

  Future<String?> toggleKudos({
    required String groupId,
    required Message message,
    required String givingUserAnonId,
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
        'kudos': [],
      });
      return null;
    } catch (_) {
      return 'Não foi possível enviar a mensagem. Tente novamente.';
    }
  }

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

        final updated = raw.map(
          (e, users) => MapEntry(e, List<String>.from(users as List)),
        );
        updated.forEach((e, users) => users.remove(anonymousId));

        updated[emoji] = (updated[emoji] ?? [])..add(anonymousId);
        updated.removeWhere((_, users) => users.isEmpty);

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
      final batch = _firestore.batch();
      batch.delete(_messagesRef(groupId).doc(messageId));
      batch.delete(_pinnedRef(groupId).doc(messageId));
      await batch.commit();
      return null;
    } catch (_) {
      return 'Não foi possível eliminar a mensagem. Tente novamente.';
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
      return 'Não foi possível fixar a mensagem. Tente novamente.';
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
      return 'Não foi possível desfixar a mensagem. Tente novamente.';
    }
  }

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

  @override
  Future<String?> toggleKudos({
    required String groupId,
    required Message message,
    required String givingUserAnonId,
  }) async {
    final messageRef = _messagesRef(groupId).doc(message.id);
    final identityRef = _firestore.collection('anonymousIdentities').doc(message.anonymousId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(messageRef);
        if (!snap.exists) throw Exception('Mensagem não encontrada.');

        final data = snap.data() ?? {};
        final kudosList = List<String>.from(data['kudos'] ?? []);

        final isAdding = !kudosList.contains(givingUserAnonId);

        if (isAdding) {
          kudosList.add(givingUserAnonId);
        } else {
          kudosList.remove(givingUserAnonId);
        }

        transaction.update(messageRef, {'kudos': kudosList});

        final identitySnap = await transaction.get(identityRef);
        if (identitySnap.exists) {
          final identityData = identitySnap.data() ?? {};
          int currentTotal = identityData['totalKudos'] as int? ?? 0;
          currentTotal = isAdding ? currentTotal + 1 : currentTotal - 1;
          if (currentTotal < 0) currentTotal = 0;
          transaction.update(identityRef, {'totalKudos': currentTotal});
        }

        if (isAdding) {
          _notifyKudosRecipient(groupId, message);
          _checkForAbuse(message.anonymousId, givingUserAnonId);
        }
      });
      return null;
    } catch (_) {
      return 'Não foi possível atualizar os Kudos. Tente novamente.';
    }
  }

  Future<void> _notifyKudosRecipient(String groupId, Message message) async {
    try {
      final identitySnap = await _firestore
          .collection('anonymousIdentities')
          .doc(message.anonymousId)
          .get();

      if (!identitySnap.exists) return;

      final recipientUserId = identitySnap.data()?['userId'] as String?;
      if (recipientUserId == null) return;

      final groupDoc = await _firestore.collection('groups').doc(groupId).get();
      final groupName = groupDoc.data()?['name'] ?? 'Comunidade';

      await _firestore.collection('notifications').add({
        'groupId': groupId,
        'groupName': groupName,
        'description': 'A tua mensagem recebeu Kudos!',
        'recipientId': recipientUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'kudos',
        'isRead': false,
      });
    } catch (e) {}
  }

  Future<void> _checkForAbuse(String recipientAnonId, String giverAnonId) async {
  }
}