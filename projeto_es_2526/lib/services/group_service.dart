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
}
