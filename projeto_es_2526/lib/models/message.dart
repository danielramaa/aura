import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String senderId; // This is now the ANONYMOUS ID
  final String senderNickname;
  final Timestamp timestamp;
  final String? replyToText;

  Message({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderNickname,
    required this.timestamp,
    this.replyToText,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      senderId: data['senderId'] ?? '',
      senderNickname: data['senderNickname'] ?? 'Anonymous',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      replyToText: data['replyToText'],
    );
  }
}