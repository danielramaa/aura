import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'group_category.dart';

class Group {
  static const int _defaultColorValue = 0xFF378ADD;

  final String id;
  final String name;
  final String description;
  final int memberCount;
  final Color color;
  final String category;

  /// True when [memberCount] is a seed estimate, not a live Firestore value.
  final bool isEstimate;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.color,
    required this.category,
    this.isEstimate = false,
  });

  factory Group.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Group(
      id: doc.id,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      color: Color((data['color'] as num?)?.toInt() ?? _defaultColorValue),
      category: groupCategories.contains(data['category'])
          ? data['category'] as String
          : 'General',
    );
  }
}
