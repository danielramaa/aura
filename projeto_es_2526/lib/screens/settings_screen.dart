import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/gdpr_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GDPRService _gdprService = GDPRService();

  Set<String> _mutedGroups = {};
  List<Map<String, dynamic>> _userGroups = [];
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        _mutedGroups = Set<String>.from(userDoc.data()?['mutedGroups'] ?? []);
      }

      final identitiesSnap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('anonymousIdentities')
          .get();

      final groupIds = identitiesSnap.docs.map((d) => d.id).toList();

      final groupDocs = await Future.wait(
        groupIds.map((gid) => _firestore.collection('groups').doc(gid).get()),
      );
      final groupsData = groupDocs
          .where((doc) => doc.exists)
          .map(
            (doc) => {'id': doc.id, 'name': doc.data()?['name'] ?? 'Unknown'},
          )
          .toList();

      if (mounted) {
        setState(() {
          _userGroups = groupsData;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleMute(String groupId, bool isMuted) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final previous = Set<String>.from(_mutedGroups);
    setState(() {
      if (isMuted) {
        _mutedGroups.add(groupId);
      } else {
        _mutedGroups.remove(groupId);
      }
    });

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'mutedGroups': _mutedGroups.toList(),
      }, SetOptions(merge: true));
    } catch (_) {
      if (mounted) {
        setState(() => _mutedGroups = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Falha ao atualizar as configurações de notificação.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isExporting = true);

    try {
      final data = await _gdprService.generateExportData(user.uid);

      // Copy to Clipboard
      final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: prettyJson));

      if (mounted) {
        setState(() => _isExporting = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green),
                SizedBox(width: 8),
                Text('Exportação Concluída'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'O conteúdo JSON com os seus dados e histórico foi copiado '
                  'para a área de transferência. Pode colá-lo onde quiser para '
                  'o guardar.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pré-visualização dos Dados:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      prettyJson,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao exportar dados. Tente novamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final controller = TextEditingController();
    bool canSubmit = false;

    try {
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('Eliminar Conta'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A sua conta será desativada e agendada para eliminação permanente em 30 dias. Durante este período, pode cancelar o processo fazendo login novamente.\n\nPara confirmar, escreva "CONFIRMAR" no campo abaixo:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Confirmação',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    setDialogState(() {
                      canSubmit = text == 'CONFIRMAR';
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: !canSubmit
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        _executeDeletion(user);
                      },
                child: const Text('Eliminar Conta'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _executeDeletion(User user) async {
    setState(() => _isDeleting = true);
    try {
      final deletionDate = await _gdprService.scheduleAccountDeletion(user.uid);

      if (mounted) {
        final dateStr =
            '${deletionDate.day.toString().padLeft(2, '0')}/'
            '${deletionDate.month.toString().padLeft(2, '0')}/'
            '${deletionDate.year}';
        // In-app confirmation of the grace period and how to cancel (the free
        // plan can't send a confirmation email). Modal so the user must
        // acknowledge it before being signed out.
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.schedule_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('Eliminação Agendada')),
              ],
            ),
            content: Text(
              'A sua conta foi agendada para eliminação permanente em $dateStr '
              '(período de carência de 30 dias).\n\n'
              'Para cancelar, basta iniciar sessão novamente antes dessa data — '
              'a sua conta será reativada automaticamente.',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Compreendi'),
              ),
            ],
          ),
        );
        await AuthService().logout();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao agendar eliminação da conta.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Definições',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Preferências de notificação',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_userGroups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Ainda não se juntou a nenhuma comunidade.'),
                  ),
                ..._userGroups.map((g) {
                  final isMuted = _mutedGroups.contains(g['id']);
                  return SwitchListTile(
                    title: Text(g['name']),
                    subtitle: Text(
                      isMuted
                          ? 'Notificações desligadas'
                          : 'Notificações ligadas',
                    ),
                    value: !isMuted,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    activeTrackColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                    onChanged: (val) => _toggleMute(g['id'], !val),
                  );
                }),
                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'Privacidade & RGPD',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: _isExporting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.download_rounded,
                          color: Color(0xFF185FA5),
                        ),
                  title: const Text('Exportar Dados'),
                  subtitle: const Text(
                    'Copiar os seus dados e histórico em formato JSON',
                  ),
                  onTap: _isExporting ? null : _exportData,
                ),
                ListTile(
                  leading: _isDeleting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.delete_forever_rounded,
                          color: Colors.red,
                        ),
                  title: const Text('Eliminar Conta'),
                  subtitle: const Text(
                    'Solicitar a eliminação permanente da sua conta',
                  ),
                  onTap: _isDeleting ? null : _deleteAccount,
                ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Terminar sessão',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Terminar sessão'),
                        content: const Text(
                          'Tem a certeza de que pretende sair?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Terminar sessão',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await AuthService().logout();
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }
                    }
                  },
                ),
              ],
            ),
    );
  }
}
