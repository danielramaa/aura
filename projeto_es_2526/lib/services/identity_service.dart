import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/anonymous_identity.dart';

class IdentityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _adjectives = ['Calm', 'Brave', 'Curious', 'Gentle', 'Silent', 'Wise', 'Happy'];
  static const _nouns = ['Wolf', 'Seal', 'Eagle', 'Lion', 'Fox', 'Bear', 'Owl'];

  Future<AnonymousIdentity> getOrCreateIdentity(String userId, String communityId) async {
    final identityDocRef = _firestore.collection('users').doc(userId).collection('anonymousIdentities').doc(communityId);
    final identityDoc = await identityDocRef.get();

    if (identityDoc.exists) {
      return AnonymousIdentity.fromMap(identityDoc.data()!);
    } else {
      final newIdentity = await _generateNewIdentity(userId, communityId);
      await identityDocRef.set(newIdentity.toMap());
      return newIdentity;
    }
  }

  Future<AnonymousIdentity> _generateNewIdentity(String userId, String communityId) async {
    final random = Random();
    final nickname = '${_adjectives[random.nextInt(_adjectives.length)]}${_nouns[random.nextInt(_nouns.length)]}${random.nextInt(99)}';
    // We use a free avatar generation service for the prototype
    final avatarUrl = 'https://api.dicebear.com/8.x/bottts-neutral/png?seed=$nickname';
    
    // This ID is what will be public on messages, completely hiding the real user ID
    final anonymousId = _firestore.collection('anonymousIdentities').doc().id;

    // Create a reverse lookup document for moderation purposes (optional but recommended)
    final reverseLookupRef = _firestore.collection('anonymousIdentities').doc(anonymousId);
    await reverseLookupRef.set({
      'userId': userId,
      'communityId': communityId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return AnonymousIdentity(
      anonymousId: anonymousId,
      nickname: nickname,
      avatarUrl: avatarUrl,
    );
  }
}