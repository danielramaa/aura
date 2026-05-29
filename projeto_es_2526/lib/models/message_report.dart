import 'package:cloud_firestore/cloud_firestore.dart';

class MessageReport {
  final String id;
  final String groupId;
  final String groupName;
  final String messageId;
  final String messageText;
  final String messageSenderAnonymousId;
  final String messageSenderNickname;
  final int messageSenderAvatarIndex;
  final String reporterAnonymousId;
  final String category;
  final String details;
  final String status;
  final Timestamp? createdAt;

  const MessageReport({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.messageId,
    required this.messageText,
    required this.messageSenderAnonymousId,
    required this.messageSenderNickname,
    required this.messageSenderAvatarIndex,
    required this.reporterAnonymousId,
    required this.category,
    required this.details,
    required this.status,
    this.createdAt,
  });

  factory MessageReport.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return MessageReport(
      id: doc.id,
      groupId: data['groupId'] as String? ?? '',
      groupName: data['groupName'] as String? ?? 'Comunidade',
      messageId: data['messageId'] as String? ?? '',
      messageText: data['messageText'] as String? ?? '',
      messageSenderAnonymousId:
          data['messageSenderAnonymousId'] as String? ?? '',
      messageSenderNickname:
          data['messageSenderNickname'] as String? ?? 'Anónimo',
      messageSenderAvatarIndex: data['messageSenderAvatarIndex'] as int? ?? 0,
      reporterAnonymousId: data['reporterAnonymousId'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      details: data['details'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
