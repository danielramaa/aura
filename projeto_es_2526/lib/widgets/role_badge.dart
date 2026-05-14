import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../services/user_service.dart';

class RoleBadge extends StatelessWidget {
  final String uid;
  const RoleBadge({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserRole>(
      stream: UserService().streamRole(uid),
      builder: (context, snap) {
        final role = snap.data ?? UserRole.user;
        final (label, color) = switch (role) {
          UserRole.admin => ('Admin', Colors.red),
          UserRole.medic => ('Medic', Colors.green),
          UserRole.user => ('User', Colors.blueGrey),
        };
        return Chip(
          label: Text(label, style: const TextStyle(color: Colors.white)),
          backgroundColor: color,
        );
      },
    );
  }
}
