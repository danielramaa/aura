import 'package:cloud_firestore/cloud_firestore.dart';

class UserReport {
  final String id;
  final String groupId;
  final String groupName;
  final String reportedAnonymousId;
  final String reportedNickname;
  final int reportedAvatarIndex;
  final String reporterAnonymousId;
  final String category;
  final String reason;
  final String description;
  final String status;
  final Timestamp? createdAt;

  const UserReport({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.reportedAnonymousId,
    required this.reportedNickname,
    required this.reportedAvatarIndex,
    required this.reporterAnonymousId,
    required this.category,
    required this.reason,
    required this.description,
    required this.status,
    this.createdAt,
  });

  factory UserReport.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserReport(
      id: doc.id,
      groupId: data['groupId'] as String? ?? '',
      groupName: data['groupName'] as String? ?? 'Community',
      reportedAnonymousId: data['reportedAnonymousId'] as String? ?? '',
      reportedNickname: data['reportedNickname'] as String? ?? 'Anonymous',
      reportedAvatarIndex: data['reportedAvatarIndex'] as int? ?? 0,
      reporterAnonymousId: data['reporterAnonymousId'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      reason: data['reason'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}
