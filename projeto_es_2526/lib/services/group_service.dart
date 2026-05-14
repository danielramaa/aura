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

          // whereIn limit is 30 — chunk to stay within it
          final chunks = <List<String>>[];
          for (var i = 0; i < groupIds.length; i += 30) {
            chunks.add(groupIds.sublist(i, (i + 30).clamp(0, groupIds.length)));
          }

          final querySnaps = await Future.wait(
            chunks.map(
              (chunk) => _groupsRef
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get(),
            ),
          );

          return querySnaps
              .expand((s) => s.docs)
              .map(Group.fromFirestore)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
        });
  }
}
