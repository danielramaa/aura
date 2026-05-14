import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group.dart';

class GroupService {
  final FirebaseFirestore _firestore;

  GroupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _groupsRef =>
      _firestore.collection('groups');

  Stream<List<Group>> streamGroups() => _groupsRef
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs.map(Group.fromFirestore).toList());

  Stream<List<String>> streamJoinedGroupIds() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('anonymousIdentities')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => doc.data()['communityId'] as String)
            .toList());
  }

  Future<void> joinGroup(String groupId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Utilizador não autenticado');

    final anonymousId = 'anon_${DateTime.now().millisecondsSinceEpoch}';

    await _firestore.collection('anonymousIdentities').add({
      'userId': user.uid,
      'communityId': groupId,
      'anonymousId': anonymousId,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await _groupsRef.doc(groupId).update({
      'memberCount': FieldValue.increment(1),
    });
  }
}