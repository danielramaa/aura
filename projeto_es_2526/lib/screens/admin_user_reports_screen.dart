import 'package:flutter/material.dart';

import '../models/user_report.dart';
import '../services/report_service.dart';
import '../services/user_service.dart';
import '../utils/avatar_utils.dart';

class AdminUserReportsScreen extends StatelessWidget {
  final UserService _userService;

  AdminUserReportsScreen({super.key, UserService? userService})
    : _userService = userService ?? UserService();

  Future<void> _handleStatus(
    BuildContext context,
    UserReport report,
    String status,
  ) async {
    final err = await _userService.updateUserReportStatus(report.id, status);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ??
              (status == 'reviewed'
                  ? 'Denúncia marcada como revista.'
                  : 'Denúncia ignorada.'),
        ),
      ),
    );
  }

  void _showReportDetails(BuildContext context, UserReport report) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Denúncia de utilizador'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AvatarUtils.buildAvatarFromAsset(
                    AvatarUtils.assetForIndex(report.reportedAvatarIndex),
                    40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.reportedNickname,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          report.groupName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailLine(
                label: 'Categoria',
                value: ReportService.labelForCategory(report.category),
              ),
              const SizedBox(height: 8),
              _DetailLine(label: 'Motivo', value: report.reason),
              const SizedBox(height: 8),
              _DetailLine(
                label: 'Descrição',
                value: report.description.isEmpty
                    ? 'Sem detalhes adicionais.'
                    : report.description,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _handleStatus(dialogContext, report, 'dismissed'),
            child: const Text('Ignorar'),
          ),
          ElevatedButton(
            onPressed: () => _handleStatus(dialogContext, report, 'reviewed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF185FA5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Marcar como revista'),
          ),
        ],
      ),
    );
  }

  String _formatTime(UserReport report) {
    final createdAt = report.createdAt;
    if (createdAt == null) return 'Agora';
    final elapsed = DateTime.now().difference(createdAt.toDate());
    if (elapsed.inMinutes < 1) return 'Agora';
    if (elapsed.inMinutes < 60) return 'Há ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'Há ${elapsed.inHours} h';
    return 'Há ${elapsed.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Denúncias de utilizadores')),
      body: StreamBuilder<List<UserReport>>(
        stream: _userService.streamPendingUserReports(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar as denúncias.'),
            );
          }
          final reports = snapshot.data ?? [];
          if (reports.isEmpty) {
            return const Center(
              child: Text(
                'Sem denúncias pendentes.',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final report = reports[index];
              final categoryLabel = ReportService.labelForCategory(
                report.category,
              );
              return Card(
                child: ListTile(
                  leading: AvatarUtils.buildAvatarFromAsset(
                    AvatarUtils.assetForIndex(report.reportedAvatarIndex),
                    40,
                  ),
                  title: Text(report.reportedNickname),
                  subtitle: Text('$categoryLabel - ${report.groupName}'),
                  trailing: Text(
                    _formatTime(report),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  onTap: () => _showReportDetails(context, report),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }
}
