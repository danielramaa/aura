import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/group.dart';

class GroupService {
  static const List<Group> defaultGroups = [
    Group(
      id: 'ansiedade-e-foco',
      name: 'Ansiedade e Foco',
      color: Color(0xFF2196F3),
      memberCount: 3500,
      description:
          'Estratégias diárias e meditação para lidar com a ansiedade e melhorar o foco no trabalho e estudos.',
      category: 'Mental Health',
    ),
    Group(
      id: 'vida-com-endometriose',
      name: 'Vida com Endometriose',
      color: Color(0xFFE91E63),
      memberCount: 1200,
      description:
          'Apoio mútuo, troca de experiências sobre médicos, tratamentos e como lidar com a dor no dia a dia.',
      category: 'Autoimmune Diseases',
    ),
    Group(
      id: 'pais-de-criancas-autistas',
      name: 'Pais de Crianças Autistas',
      color: Color(0xFFFF9800),
      memberCount: 4800,
      description:
          'Comunidade acolhedora para partilhar vitórias, desafios e recursos sobre o espetro autista.',
      category: 'Neurodivergence',
    ),
  ];


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

          // Fetch all joined IDs from Firestore — whereIn limit is 30, chunk to stay within it.
          final chunks = <List<String>>[];
          for (var i = 0; i < groupIds.length; i += 30) {
            chunks.add(groupIds.sublist(i, (i + 30).clamp(0, groupIds.length)));
          }
          final querySnaps = await Future.wait(
            chunks.map(
              (chunk) =>
                  _groupsRef.where(FieldPath.documentId, whereIn: chunk).get(),
            ),
          );

          // Firestore wins when the document exists and is complete (has a name).
          // Fall back to seed for missing or partial documents.
          final firestoreMap = <String, Group>{};
          for (final doc in querySnaps.expand((s) => s.docs)) {
            final g = Group.fromFirestore(doc);
            if (g.name.isNotEmpty) firestoreMap[g.id] = g;
          }

          final defaultMap = {for (final g in defaultGroups) g.id: g};

          final result = <Group>[];
          for (final id in groupIds) {
            final group = firestoreMap[id] ?? defaultMap[id];
            if (group != null) result.add(group);
          }

          return result..sort((a, b) => a.name.compareTo(b.name));
        });
  }
}
