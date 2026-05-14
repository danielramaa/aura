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

  Future<String?> createPoll({
    required String groupId,
    required String question,
    required List<String> options,
    required AnonymousIdentity identity,
  });

  Future<String?> votePoll({
    required String groupId,
    required String messageId,
    required String anonymousId,
    required String optionId,
  });

  Future<String?> closePoll({
    required String groupId,
    required String messageId,
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
        'replyToText': replyToText,
        'mentions': mentions,
        'reactions': {},
        'type': 'text',
      });
      return null;
    } catch (_) {
      return 'Failed to send message. Please try again.';
    }
  }

  @override
  Future<String?> createPoll({
    required String groupId,
    required String question,
    required List<String> options,
    required AnonymousIdentity identity,
  }) async {
    final trimmedQuestion = question.trim();
    final cleanedOptions = options
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();

    if (trimmedQuestion.isEmpty) return 'Poll question cannot be empty.';
    if (cleanedOptions.length < 2) return 'Poll must have at least 2 options.';
    if (cleanedOptions.length > 6) return 'Poll can have at most 6 options.';

    try {
      final pollOptions = cleanedOptions
          .asMap()
          .entries
          .map(
            (entry) => {
              'id': 'option_${entry.key}',
              'text': entry.value,
              'votes': 0,
            },
          )
          .toList();

      await _messagesRef(groupId).add({
        'text': '',
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': identity.anonymousId,
        'senderNickname': identity.nickname,
        'replyToText': null,
        'mentions': [],
        'reactions': {},
        'type': 'poll',
        'pollData': {
          'question': trimmedQuestion,
          'options': pollOptions,
          'isClosed': false,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24)),
          ),
          'voterIds': [],
        },
      });

      return null;
    } catch (_) {
      return 'Failed to create poll. Please try again.';
    }
  }

  @override
  Future<String?> votePoll({
    required String groupId,
    required String messageId,
    required String anonymousId,
    required String optionId,
  }) async {
    final docRef = _messagesRef(groupId).doc(messageId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);

        if (!snap.exists) {
          throw Exception('Poll not found.');
        }

        final data = snap.data() ?? {};

        if (data['type'] != 'poll') {
          throw Exception('Message is not a poll.');
        }

        final pollData = Map<String, dynamic>.from(data['pollData'] ?? {});

        final isClosed = pollData['isClosed'] ?? false;
        final expiresAt = pollData['expiresAt'] as Timestamp?;
        final voterIds = List<String>.from(pollData['voterIds'] ?? []);

        if (isClosed) {
          throw Exception('Poll is closed.');
        }

        if (expiresAt != null && DateTime.now().isAfter(expiresAt.toDate())) {
          pollData['isClosed'] = true;
          transaction.update(docRef, {'pollData': pollData});
          throw Exception('Poll expired.');
        }

        if (voterIds.contains(anonymousId)) {
          throw Exception('User already voted.');
        }

        final options = List<Map<String, dynamic>>.from(
          (pollData['options'] ?? []).map(
            (o) => Map<String, dynamic>.from(o),
          ),
        );

        bool found = false;

        for (int i = 0; i < options.length; i++) {
          if (options[i]['id'] == optionId) {
            options[i]['votes'] = (options[i]['votes'] ?? 0) + 1;
            found = true;
            break;
          }
        }

        if (!found) {
          throw Exception('Invalid option.');
        }

        voterIds.add(anonymousId);

        pollData['options'] = options;
        pollData['voterIds'] = voterIds;

        transaction.update(docRef, {
          'pollData': pollData,
        });
      });

      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  @override
  Future<String?> closePoll({
    required String groupId,
    required String messageId,
  }) async {
    final docRef = _messagesRef(groupId).doc(messageId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);

        if (!snap.exists) {
          throw Exception('Poll not found.');
        }

        final data = snap.data() ?? {};

        if (data['type'] != 'poll') {
          throw Exception('Message is not a poll.');
        }

        final pollData = Map<String, dynamic>.from(data['pollData'] ?? {});
        pollData['isClosed'] = true;

        transaction.update(docRef, {
          'pollData': pollData,
        });
      });

      return null;
    } catch (_) {
      return 'Failed to close poll.';
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
        if (!snap.exists) throw Exception('Message not found.');

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
      return 'Não foi possível adicionar a reação. Tente novamente.';
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
