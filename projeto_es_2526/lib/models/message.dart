import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String text;
  final String anonymousId;
  final String senderNickname;
  final Timestamp timestamp;
  final String? replyToText;

  Message({
    required this.id,
    required this.text,
    required this.anonymousId,
    required this.senderNickname,
    required this.timestamp,
    this.replyToText,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      text: data['text'] ?? '',
      anonymousId: data['senderId'] ?? '',
      senderNickname: data['senderNickname'] ?? 'Anonymous',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      replyToText: data['replyToText'],
    );
  }
}
