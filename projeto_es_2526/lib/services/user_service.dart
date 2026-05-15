import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/moderator_application.dart';
import '../models/user_role.dart';

class UserService {
  final FirebaseFirestore _firestore;

  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<UserRole> streamRole(String uid) => _userDoc(uid).snapshots().map(
    (snap) => UserRole.fromString(snap.data()?['role'] as String?),
  );

  Future<UserRole> getRole(String uid) async {
    final snap = await _userDoc(uid).get();
    return UserRole.fromString(snap.data()?['role'] as String?);
  }

  Stream<List<ModeratorApplication>> streamPendingApplications() {
    return _firestore
        .collection('moderator_applications')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs.map(ModeratorApplication.fromFirestore).toList(),
        );
  }

  Future<String?> approveApplication(String appId, String userId) async {
    try {
      final batch = _firestore.batch();
      batch.update(_firestore.collection('moderator_applications').doc(appId), {
        'status': 'approved',
      });
      batch.update(_userDoc(userId), {'role': 'medic'});
      await batch.commit();
      return null;
    } catch (_) {
      return 'Failed to approve application.';
    }
  }

  Future<String?> denyApplication(String appId) async {
    try {
      await _firestore.collection('moderator_applications').doc(appId).update({
        'status': 'denied',
      });
      return null;
    } catch (_) {
      return 'Failed to deny application.';
    }
  }
}
