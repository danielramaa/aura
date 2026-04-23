import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message.dart';

abstract class ChatServiceInterface {
  Stream<List<Message>> streamMessages(String groupId);
  Future<void> sendMessage({required String groupId, required String text});
}

class ChatService implements ChatServiceInterface {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('messages');

  @override
  Stream<List<Message>> streamMessages(String groupId) => _messagesRef(groupId)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map(Message.fromFirestore).toList());

  @override
  Future<void> sendMessage({
    required String groupId,
    required String text,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw StateError('sendMessage called while unauthenticated');
    await _messagesRef(groupId).add(
      Message.newMessagePayload(text: text, senderId: currentUser.uid),
    );
  }
}

// ================== TYPING INDICATOR ==================

Future<void> setTyping(String groupId, String userId, String nickname) async {
  await FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('typing')
      .doc(userId)
      .set({
    'nickname': nickname,
    'timestamp': FieldValue.serverTimestamp(),
  });
}

Future<void> stopTyping(String groupId, String userId) async {
  await FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('typing')
      .doc(userId)
      .delete();
}

Stream<QuerySnapshot> typingStream(String groupId) {
  return FirebaseFirestore.instance
      .collection('groups')
      .doc(groupId)
      .collection('typing')
      .snapshots();
}