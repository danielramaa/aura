import 'package:flutter/material.dart';

class Group {
  final String id;
  final String name;
  final String description;
  final int memberCount;
  final Color color;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.color,
  });
}
