import 'package:cloud_firestore/cloud_firestore.dart';

class PinnedMessage {
  final String messageId;
  final String text;
  final String senderNickname;
  final int senderAvatarIndex;
  final Timestamp messageTimestamp;
  final Timestamp pinnedAt;

  PinnedMessage({
    required this.messageId,
    required this.text,
    required this.senderNickname,
    required this.senderAvatarIndex,
    required this.messageTimestamp,
    required this.pinnedAt,
  });

  factory PinnedMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final nickname = data['senderNickname'] as String? ?? '';
    return PinnedMessage(
      messageId: doc.id,
      text: data['text'] as String? ?? '',
      senderNickname: nickname.isEmpty ? 'Anonymous' : nickname,
      senderAvatarIndex: data['senderAvatarIndex'] as int? ?? 0,
      messageTimestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      pinnedAt: data['pinnedAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}
