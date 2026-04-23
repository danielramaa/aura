import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message.dart';
import 'identity_service.dart';

abstract class ChatServiceInterface {
  Stream<List<Message>> streamMessages(String groupId);
  Future<void> sendMessage({
    required String groupId,
    required String text,
    String? replyToText,
  });
}

/// Sends and streams messages using the caller's anonymous identity,
/// so no real user identifier is ever stored in the messages collection.
class ChatService implements ChatServiceInterface {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final IdentityService _identityService;

  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    IdentityService? identityService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _identityService = identityService ?? IdentityService();

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('messages');

  @override
  Stream<List<Message>> streamMessages(String groupId) =>
      _messagesRef(groupId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map(Message.fromFirestore).toList());

  @override
  Future<void> sendMessage({
    required String groupId,
    required String text,
    String? replyToText,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('sendMessage called while unauthenticated');

    final identity =
        await _identityService.getOrCreateIdentity(user.uid, groupId);

    await _messagesRef(groupId).add({
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'senderId': identity.anonymousId,
      'senderNickname': identity.nickname,
      'replyToText': replyToText,
    });
  }
}
