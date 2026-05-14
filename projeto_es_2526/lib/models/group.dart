import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Group {
  static const int _defaultColorValue = 0xFF378ADD;

  final String id;
  final String name;
  final String description;
  final int memberCount;
  final Color color;
  final String category;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.color,
    required this.category,
  });

  factory Group.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Group(
      id: doc.id,
      name: data['name'] as String,
      description: data['description'] as String,
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      color: Color((data['color'] as num?)?.toInt() ?? _defaultColorValue),
      category: data['category'] as String? ?? 'General',
    );
  }
}
