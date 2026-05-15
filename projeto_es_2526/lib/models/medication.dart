import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  final String id;
  final String groupId;
  final String name;
  final String description;
  final String status;
  final String submittedByUserId;
  final Timestamp? timestamp;

  Medication({
    required this.id,
    required this.groupId,
    required this.name,
    required this.description,
    required this.status,
    required this.submittedByUserId,
    this.timestamp,
  });

  factory Medication.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Medication(
      id: doc.id,
      groupId: data['groupId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      submittedByUserId: data['submittedByUserId'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp?,
    );
  }
}
