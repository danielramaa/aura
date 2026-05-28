import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/message_report.dart';
import '../models/user_report.dart';
import '../services/report_service.dart';
import '../services/user_service.dart';
import '../utils/avatar_utils.dart';

class AdminReportsScreen extends StatelessWidget {
  final UserService _userService;

  AdminReportsScreen({super.key, UserService? userService})
    : _userService = userService ?? UserService();

  String _formatTime(Timestamp? createdAt) {
    if (createdAt == null) return 'Agora';
    // Clamp negative durations (device clock ahead of the serverTimestamp) to
    // zero so a just-created report never renders an invalid "Há -1 min".
    final rawElapsed = DateTime.now().difference(createdAt.toDate());
    final elapsed = rawElapsed.isNegative ? Duration.zero : rawElapsed;
    if (elapsed.inMinutes < 1) return 'Agora';
    if (elapsed.inMinutes < 60) return 'Há ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'Há ${elapsed.inHours} h';
    return 'Há ${elapsed.inDays} d';
  }

  Future<void> _handleUserReportStatus(
    BuildContext context,
    UserReport report,
    String status,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final err = await _userService.updateUserReportStatus(report.id, status);
    if (!navigator.mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(_statusMessage(err, status))),
    );
  }

  Future<void> _handleMessageReportStatus(
    BuildContext context,
    MessageReport report,
    String status,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final err = await _userService.updateMessageReportStatus(report.id, status);
    if (!navigator.mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text(_statusMessage(err, status))),
    );
  }

  String _statusMessage(String? err, String status) {
    if (err != null) return err;
    return status == 'reviewed'
        ? 'Denúncia marcada como revista.'
        : 'Denúncia ignorada.';
  }

  void _showUserReportDetails(BuildContext context, UserReport report) {
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
            onPressed: () =>
                _handleUserReportStatus(dialogContext, report, 'dismissed'),
            child: const Text('Ignorar'),
          ),
          ElevatedButton(
            onPressed: () =>
                _handleUserReportStatus(dialogContext, report, 'reviewed'),
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

  void _showMessageReportDetails(BuildContext context, MessageReport report) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Denúncia de mensagem'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AvatarUtils.buildAvatarFromAsset(
                    AvatarUtils.assetForIndex(report.messageSenderAvatarIndex),
                    40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.messageSenderNickname,
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
                value: ReportService.labelForMessageCategory(report.category),
              ),
              const SizedBox(height: 8),
              _DetailLine(label: 'Mensagem', value: report.messageText),
              const SizedBox(height: 8),
              _DetailLine(
                label: 'Detalhes',
                value: report.details.isEmpty
                    ? 'Sem detalhes adicionais.'
                    : report.details,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                _handleMessageReportStatus(dialogContext, report, 'dismissed'),
            child: const Text('Ignorar'),
          ),
          ElevatedButton(
            onPressed: () =>
                _handleMessageReportStatus(dialogContext, report, 'reviewed'),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Denúncias'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Utilizadores'),
              Tab(text: 'Mensagens'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildUserReportsTab(), _buildMessageReportsTab()],
        ),
      ),
    );
  }

  Widget _buildUserReportsTab() {
    return StreamBuilder<List<UserReport>>(
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
              'Sem denúncias de utilizadores pendentes.',
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
                  _formatTime(report.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                onTap: () => _showUserReportDetails(context, report),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageReportsTab() {
    return StreamBuilder<List<MessageReport>>(
      stream: _userService.streamPendingMessageReports(),
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
              'Sem denúncias de mensagens pendentes.',
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
            final categoryLabel = ReportService.labelForMessageCategory(
              report.category,
            );
            return Card(
              child: ListTile(
                leading: AvatarUtils.buildAvatarFromAsset(
                  AvatarUtils.assetForIndex(report.messageSenderAvatarIndex),
                  40,
                ),
                title: Text(report.messageSenderNickname),
                subtitle: Text(
                  '$categoryLabel - ${report.messageText}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _formatTime(report.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                onTap: () => _showMessageReportDetails(context, report),
              ),
            );
          },
        );
      },
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
