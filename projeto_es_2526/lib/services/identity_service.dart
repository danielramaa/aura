import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/anonymous_identity.dart';
import '../utils/avatar_utils.dart';

class IdentityService {
  final FirebaseFirestore _firestore;

  IdentityService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _adjectives = [
    'Calm',
    'Brave',
    'Curious',
    'Gentle',
    'Silent',
    'Wise',
    'Happy',
    'Swift',
    'Bold',
    'Keen',
    'Daring',
    'Bright',
    'Serene',
    'Nimble',
    'Quiet',
    'Fierce',
    'Clever',
    'Noble',
    'Vivid',
    'Tender',
  ];
  static const _nouns = [
    'Wolf',
    'Seal',
    'Eagle',
    'Lion',
    'Fox',
    'Bear',
    'Owl',
    'Hawk',
    'Deer',
    'Otter',
    'Raven',
    'Tiger',
    'Lynx',
    'Crane',
    'Heron',
    'Bison',
    'Moose',
    'Panda',
    'Koala',
    'Gecko',
  ];

  Future<AnonymousIdentity> getOrCreateIdentity(
    String userId,
    String groupId,
  ) async {
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
      // Identity is now committed — increment memberCount.
      // Ignore not-found: default/seeded groups have no Firestore document.
      try {
        await _firestore.collection('groups').doc(groupId).update({
          'memberCount': FieldValue.increment(1),
        });
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') {
          debugPrint('memberCount increment failed for $groupId: $e');
        }
      }
      return newIdentity;
    }
  }

  Future<void> leaveGroup(String userId, String groupId) async {
    final userIdentityRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('anonymousIdentities')
        .doc(groupId);

    final groupDocRef = _firestore.collection('groups').doc(groupId);

    // Read identity and group doc in parallel.
    final userIdentityDoc = await userIdentityRef.get();
    if (!userIdentityDoc.exists) return;
    final groupDoc = await groupDocRef.get();

    final data = userIdentityDoc.data()!;
    final anonymousId = data['anonymousId'] as String?;
    final nickname = data['nickname'] as String?;
    final avatarIndex = data['avatarIndex'] as int?;

    final batch = _firestore.batch();

    // Decrement memberCount atomically with the identity deletion.
    // Skip if the group has no Firestore document (default/seeded groups).
    if (groupDoc.exists) {
      batch.update(groupDocRef, {'memberCount': FieldValue.increment(-1)});
    }

    batch.delete(userIdentityRef);

    if (anonymousId != null) {
      batch.set(
        _firestore.collection('anonymousIdentities').doc(anonymousId),
        {'leftAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }

    if (nickname != null) {
      batch.delete(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('takenNicknames')
            .doc(nickname),
      );
    }

    if (avatarIndex != null) {
      batch.delete(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('takenAvatarIndices')
            .doc('$avatarIndex'),
      );
    }

    await batch.commit();
  }

  Future<AnonymousIdentity> _generateNewIdentity(
    String userId,
    String groupId,
  ) async {
    final nickname = await _generateUniqueNickname(groupId);
    final avatarIndex = await _reserveAvatarIndex(groupId, nickname);
    final anonymousId = _firestore.collection('anonymousIdentities').doc().id;

    // Reverse lookup for moderation: maps anonymousId → real userId
    final reverseLookupRef = _firestore
        .collection('anonymousIdentities')
        .doc(anonymousId);
    await reverseLookupRef.set({
      'userId': userId,
      'groupId': groupId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return AnonymousIdentity(
      anonymousId: anonymousId,
      nickname: nickname,
      avatarIndex: avatarIndex,
    );
  }

  /// Reserves a unique avatar slot in the group and returns its index (0–19).
  /// Falls back to a hash-derived index when all slots are taken (>20 members).
  Future<int> _reserveAvatarIndex(String groupId, String nickname) async {
    final preferred =
        nickname.codeUnits.fold(0, (acc, c) => acc + c) % AvatarUtils.count;
    final takenRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('takenAvatarIndices');

    for (int attempt = 0; attempt < AvatarUtils.count; attempt++) {
      final index = (preferred + attempt) % AvatarUtils.count;
      try {
        await _firestore.runTransaction((tx) async {
          final doc = await tx.get(takenRef.doc('$index'));
          if (doc.exists) throw Exception('taken');
          tx.set(takenRef.doc('$index'), {
            'takenAt': FieldValue.serverTimestamp(),
          });
        });
        return index;
      } on Exception catch (e) {
        if (e.toString().contains('taken')) continue;
        rethrow;
      }
    }
    // All 20 slots taken (>20 members): collision unavoidable, fall back to hash.
    return preferred;
  }

  Future<String> _generateUniqueNickname(String groupId) async {
    final random = Random();
    final takenRef = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('takenNicknames');

    String makeCandidate() =>
        '${_adjectives[random.nextInt(_adjectives.length)]}'
        '${_nouns[random.nextInt(_nouns.length)]}'
        '${random.nextInt(99)}';

    Future<bool> tryReserve(String nickname) async {
      try {
        await _firestore.runTransaction((tx) async {
          final doc = await tx.get(takenRef.doc(nickname));
          if (doc.exists) throw Exception('taken');
          tx.set(takenRef.doc(nickname), {
            'takenAt': FieldValue.serverTimestamp(),
          });
        });
        return true;
      } on Exception catch (e) {
        if (e.toString().contains('taken')) return false;
        rethrow; // surface real errors (permission, network, etc.)
      }
    }

    for (int i = 0; i < 10; i++) {
      final candidate = makeCandidate();
      if (await tryReserve(candidate)) return candidate;
    }

    // Fallback after 10 collisions: timestamp suffix guarantees uniqueness
    final fallback =
        '${_adjectives[random.nextInt(_adjectives.length)]}'
        '${_nouns[random.nextInt(_nouns.length)]}'
        '${DateTime.now().millisecondsSinceEpoch % 9999}';
    await tryReserve(fallback); // reserve it too; rethrows on real errors
    return fallback;
  }
}
