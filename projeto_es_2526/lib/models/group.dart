import 'package:flutter/material.dart';

class Group {
  final String name;
  final String lastMessage;
  final String time;
  final Color color;
  final int unreadCount;
  final bool isOnline;
  final int memberCount;

  const Group({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.color,
    required this.unreadCount,
    required this.isOnline,
    required this.memberCount,
  });
}
