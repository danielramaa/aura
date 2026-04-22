import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) =>
      _firestore.collection('groups').doc(groupId).collection('messages');

  Stream<List<Message>> streamMessages(String groupId) => _messagesRef(groupId)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map(Message.fromFirestore).toList());

  Future<void> sendMessage({
    required String groupId,
    required String text,
  }) {
    final uid = _auth.currentUser!.uid;
    return _messagesRef(groupId).add(
      Message.newMessagePayload(text: text, senderId: uid),
    );
  }
}
