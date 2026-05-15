import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication.dart';

class MedicationService {
  final FirebaseFirestore _firestore;

  MedicationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<Medication>> streamApprovedMedications(String groupId) {
    return _firestore
        .collection('medications')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .map((snap) {
      final meds = snap.docs.map(Medication.fromFirestore).toList();
      meds.sort((a, b) {
        final aTime = a.timestamp?.toDate() ?? DateTime.now();
        final bTime = b.timestamp?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      return meds;
    });
  }

  Future<String?> submitMedication({
    required String groupId, required String name, required String description, required String userId,
  }) async {
    try {
      await _firestore.collection('medications').add({
        'groupId': groupId, 'name': name, 'description': description,
        'status': 'approved', 'submittedByUserId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return 'Failed to add medication. Please try again.';
    }
  }
}
