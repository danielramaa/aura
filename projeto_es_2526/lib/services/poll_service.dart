import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/anonymous_identity.dart';
import '../models/poll.dart';

abstract class PollServiceInterface {
  Stream<Poll> streamPoll(String groupId, String pollId);

  Stream<int?> streamUserVote(
    String groupId,
    String pollId,
    String anonymousId,
  );

  Future<String?> createPoll({
    required String groupId,
    required String question,
    required List<String> optionTexts,
    required AnonymousIdentity identity,
  });

  Future<String?> vote({
    required String groupId,
    required String pollId,
    required int optionIndex,
    required String anonymousId,
  });

  Future<String?> closePoll({
    required String groupId,
    required String pollId,
    required String anonymousId,
  });
}

class PollService implements PollServiceInterface {
  final FirebaseFirestore _firestore;

  PollService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _pollsRef(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('polls');

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('messages');

  CollectionReference<Map<String, dynamic>> _votesRef(
    String groupId,
    String pollId,
  ) => _pollsRef(groupId).doc(pollId).collection('votes');

  @override
  Stream<Poll> streamPoll(String groupId, String pollId) => _pollsRef(groupId)
      .doc(pollId)
      .snapshots()
      .where((snap) => snap.exists)
      .map(Poll.fromFirestore);

  @override
  Stream<int?> streamUserVote(
    String groupId,
    String pollId,
    String anonymousId,
  ) => _votesRef(groupId, pollId).doc(anonymousId).snapshots().map((snap) {
    if (!snap.exists) return null;
    return (snap.data()?['optionIndex'] as num?)?.toInt();
  });

  @override
  Future<String?> createPoll({
    required String groupId,
    required String question,
    required List<String> optionTexts,
    required AnonymousIdentity identity,
  }) async {
    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) return 'A pergunta não pode estar vazia.';

    final trimmedOptions = optionTexts.map((o) => o.trim()).toList();
    if (trimmedOptions.length < 2) {
      return 'A sondagem deve ter pelo menos 2 opções.';
    }
    if (trimmedOptions.length > 6) {
      return 'A sondagem não pode ter mais de 6 opções.';
    }
    if (trimmedOptions.any((o) => o.isEmpty)) {
      return 'Todas as opções devem conter texto.';
    }

    try {
      final pollRef = _pollsRef(groupId).doc();
      final batch = _firestore.batch();

      batch.set(pollRef, {
        'question': trimmedQuestion,
        'options': trimmedOptions
            .map((text) => {'text': text, 'voteCount': 0})
            .toList(),
        'creatorAnonymousId': identity.anonymousId,
        'createdAt': FieldValue.serverTimestamp(),
        'closedAt': null,
      });

      final msgRef = _messagesRef(groupId).doc();
      batch.set(msgRef, {
        'type': 'poll',
        'pollId': pollRef.id,
        'text': '',
        'senderId': identity.anonymousId,
        'senderNickname': identity.nickname,
        'senderAvatarIndex': identity.avatarIndex,
        'timestamp': FieldValue.serverTimestamp(),
        'mentions': [],
        'reactions': {},
      });

      await batch.commit();
      return null;
    } catch (_) {
      return 'Não foi possível criar a sondagem. Tente novamente.';
    }
  }

  @override
  Future<String?> vote({
    required String groupId,
    required String pollId,
    required int optionIndex,
    required String anonymousId,
  }) async {
    final pollRef = _pollsRef(groupId).doc(pollId);
    final voteRef = _votesRef(groupId, pollId).doc(anonymousId);

    try {
      await _firestore.runTransaction((tx) async {
        final pollSnap = await tx.get(pollRef);
        if (!pollSnap.exists) throw Exception('Poll not found.');

        final poll = Poll.fromFirestore(pollSnap);
        if (!poll.isOpen) throw Exception('Poll is closed.');

        final voteSnap = await tx.get(voteRef);
        if (voteSnap.exists) throw Exception('Already voted.');

        if (optionIndex < 0 || optionIndex >= poll.options.length) {
          throw Exception('Invalid option.');
        }

        final rawOptions = List<Map<String, dynamic>>.from(
          (pollSnap.data()!['options'] as List).map(
            (o) => Map<String, dynamic>.from(o as Map),
          ),
        );
        rawOptions[optionIndex]['voteCount'] =
            (rawOptions[optionIndex]['voteCount'] as num) + 1;

        tx.update(pollRef, {'options': rawOptions});
        tx.set(voteRef, {'optionIndex': optionIndex});
      });
      return null;
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('Poll is closed')) return 'Esta sondagem está encerrada.';
      if (msg.contains('Already voted')) return 'Você já votou.';
      return 'Não foi possível enviar o voto. Tente novamente.';
    }
  }

  @override
  Future<String?> closePoll({
    required String groupId,
    required String pollId,
    required String anonymousId,
  }) async {
    final pollRef = _pollsRef(groupId).doc(pollId);

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(pollRef);
        if (!snap.exists) throw Exception('Poll not found.');

        final data = snap.data()!;
        if (data['creatorAnonymousId'] != anonymousId) {
          throw Exception('Not the creator.');
        }

        tx.update(pollRef, {'closedAt': FieldValue.serverTimestamp()});
      });
      return null;
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('Not the creator')) {
        return 'Somente o criador da sondagem pode fechá-la.';
      }
      return 'Não foi possível fechar a sondagem. Tente novamente.';
    }
  }
}
