import 'package:cloud_firestore/cloud_firestore.dart';

class ModeratorApplication {
  final String id;
  final String userId;
  final String userEmail;
  final String licenseNumber;
  final String status;
  final Timestamp? timestamp;

  ModeratorApplication({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.licenseNumber,
    required this.status,
    this.timestamp,
  });

  factory ModeratorApplication.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ModeratorApplication(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      licenseNumber: data['licenseNumber'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      timestamp: data['timestamp'] as Timestamp?,
    );
  }
}
