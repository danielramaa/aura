import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/anonymous_identity.dart';

class IdentityService {
  final FirebaseFirestore _firestore;

  IdentityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _adjectives = [
    'Calm', 'Brave', 'Curious', 'Gentle', 'Silent', 'Wise', 'Happy',
    'Swift', 'Bold', 'Keen', 'Daring', 'Bright', 'Serene', 'Nimble',
    'Quiet', 'Fierce', 'Clever', 'Noble', 'Vivid', 'Tender',
  ];
  static const _nouns = [
    'Wolf', 'Seal', 'Eagle', 'Lion', 'Fox', 'Bear', 'Owl',
    'Hawk', 'Deer', 'Otter', 'Raven', 'Tiger', 'Lynx', 'Crane',
    'Heron', 'Bison', 'Moose', 'Panda', 'Koala', 'Gecko',
  ];

  Future<AnonymousIdentity> getOrCreateIdentity(String userId, String groupId) async {
    final identityDocRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('anonymousIdentities')
        .doc(groupId);
    final identityDoc = await identityDocRef.get();

    if (identityDoc.exists) {
      return AnonymousIdentity.fromMap(identityDoc.data()!);
    } else {
      final newIdentity = await _generateNewIdentity(userId, groupId);
      await identityDocRef.set(newIdentity.toMap());
      return newIdentity;
    }
  }

  Future<AnonymousIdentity> _generateNewIdentity(String userId, String groupId) async {
    final nickname = await _generateUniqueNickname(groupId);
    // TODO: generate avatar locally to avoid leaking user IPs to a third party
    const avatarUrl = '';
    final anonymousId = _firestore.collection('anonymousIdentities').doc().id;

    // Reverse lookup for moderation: maps anonymousId → real userId
    final reverseLookupRef = _firestore.collection('anonymousIdentities').doc(anonymousId);
    await reverseLookupRef.set({
      'userId': userId,
      'groupId': groupId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return AnonymousIdentity(
      anonymousId: anonymousId,
      nickname: nickname,
      avatarUrl: avatarUrl,
    );
  }

  Future<String> _generateUniqueNickname(String groupId) async {
    final random = Random();
    final takenRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('takenNicknames');

    String _candidate() =>
        '${_adjectives[random.nextInt(_adjectives.length)]}'
        '${_nouns[random.nextInt(_nouns.length)]}'
        '${random.nextInt(99)}';

    Future<bool> _tryReserve(String nickname) async {
      try {
        await _firestore.runTransaction((tx) async {
          final doc = await tx.get(takenRef.doc(nickname));
          if (doc.exists) throw Exception('taken');
          tx.set(takenRef.doc(nickname), {'takenAt': FieldValue.serverTimestamp()});
        });
        return true;
      } on Exception catch (e) {
        if (e.toString().contains('taken')) return false;
        rethrow; // surface real errors (permission, network, etc.)
      }
    }

    for (int i = 0; i < 10; i++) {
      final candidate = _candidate();
      if (await _tryReserve(candidate)) return candidate;
    }

    // Fallback after 10 collisions: timestamp suffix guarantees uniqueness
    final fallback =
        '${_adjectives[random.nextInt(_adjectives.length)]}'
        '${_nouns[random.nextInt(_nouns.length)]}'
        '${DateTime.now().millisecondsSinceEpoch % 9999}';
    await _tryReserve(fallback); // reserve it too; rethrows on real errors
    return fallback;
  }
}
