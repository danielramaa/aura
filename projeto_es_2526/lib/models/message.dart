import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String senderId;
  final DateTime? createdAt;

  const Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.createdAt,
  });

  factory Message.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return Message(
      id: doc.id,
      text: data['text'] as String,
      senderId: data['senderId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> newMessagePayload({
    required String text,
    required String senderId,
  }) => {
    'text': text,
    'senderId': senderId,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
