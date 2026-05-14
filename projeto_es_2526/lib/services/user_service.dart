import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_role.dart';

class UserService {
  final FirebaseFirestore _firestore;

  UserService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<UserRole> streamRole(String uid) => _userDoc(uid)
      .snapshots()
      .map((snap) => UserRole.fromString(snap.data()?['role'] as String?));

  Future<UserRole> getRole(String uid) async {
    final snap = await _userDoc(uid).get();
    return UserRole.fromString(snap.data()?['role'] as String?);
  }
}
