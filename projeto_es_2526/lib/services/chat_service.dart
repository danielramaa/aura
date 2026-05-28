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
      await _messagesRef(groupId).doc(messageId).delete();
      return null;
    } catch (_) {
      return 'Não foi possível excluir a mensagem. Por favor tente novamente.';
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
}
