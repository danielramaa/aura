import 'package:cloud_firestore/cloud_firestore.dart';

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

  Stream<List<Group>> streamJoinedGroups(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('anonymousIdentities')
        .snapshots()
        .asyncMap((snap) async {
          final groupIds = snap.docs.map((d) => d.id).toList();
          if (groupIds.isEmpty) return <Group>[];
          final docs = await Future.wait(
            groupIds.map((id) => _groupsRef.doc(id).get()),
          );
          return docs.where((d) => d.exists).map(Group.fromFirestore).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
        });
  }
}
