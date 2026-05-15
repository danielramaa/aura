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
        .snapshots()
        .map((snap) {
      final allMeds = snap.docs.map(Medication.fromFirestore).toList();
      final approved = allMeds.where((m) => m.status == 'approved').toList();
      
      approved.sort((a, b) {
        final aTime = a.timestamp?.toDate() ?? DateTime.now();
        final bTime = b.timestamp?.toDate() ?? DateTime.now();
        return bTime.compareTo(aTime);
      });
      return approved;
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
      if (e.toString().contains('permission-denied')) {
        return 'Falha: Sem permissão. (Atualize as Regras de Segurança do Firestore)';
      }
      return 'Failed to submit medication: $e';
    }
  }
}