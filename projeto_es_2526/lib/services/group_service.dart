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

          final defaultMap = {for (final g in defaultGroups) g.id: g};
          final defaultMatches =
              groupIds.where(defaultMap.containsKey).map((id) => defaultMap[id]!).toList();

          final remoteIds = groupIds.where((id) => !defaultMap.containsKey(id)).toList();

          List<Group> remoteGroups = [];
          if (remoteIds.isNotEmpty) {
            // whereIn limit is 30 — chunk to stay within it
            final chunks = <List<String>>[];
            for (var i = 0; i < remoteIds.length; i += 30) {
              chunks.add(remoteIds.sublist(i, (i + 30).clamp(0, remoteIds.length)));
            }
            final querySnaps = await Future.wait(
              chunks.map(
                (chunk) =>
                    _groupsRef.where(FieldPath.documentId, whereIn: chunk).get(),
              ),
            );
            remoteGroups = querySnaps
                .expand((s) => s.docs)
                .map(Group.fromFirestore)
                .toList();
          }

          return [...defaultMatches, ...remoteGroups]
            ..sort((a, b) => a.name.compareTo(b.name));
        });
  }
}
