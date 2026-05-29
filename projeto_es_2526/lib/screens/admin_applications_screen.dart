import 'package:flutter/material.dart';

import '../models/moderator_application.dart';
import '../services/user_service.dart';

class AdminApplicationsScreen extends StatelessWidget {
  final UserService _userService = UserService();

  AdminApplicationsScreen({super.key});

  void _handleDecision(
    BuildContext context,
    ModeratorApplication app,
    bool approve,
  ) async {
    final String? err;
    if (approve) {
      err = await _userService.approveApplication(app.id, app.userId);
    } else {
      err = await _userService.denyApplication(app.id);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err ?? (approve ? 'Candidatura aprovada.' : 'Candidatura negada.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidaturas para moderador')),
      body: StreamBuilder<List<ModeratorApplication>>(
        stream: _userService.streamPendingApplications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Falha ao carregar candidaturas.'));
          }
          final apps = snapshot.data ?? [];
          if (apps.isEmpty) {
            return const Center(
              child: Text(
                'Sem candidaturas pendentes.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              final app = apps[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.userEmail.isNotEmpty ? app.userEmail : app.userId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Licença: ${app.licenseNumber}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                _handleDecision(context, app, false),
                            child: const Text(
                              'Recusar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () =>
                                _handleDecision(context, app, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF185FA5),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Aprovar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
