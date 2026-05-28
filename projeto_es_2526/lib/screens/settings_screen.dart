import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Set<String> _mutedGroups = {};
  List<Map<String, dynamic>> _userGroups = [];
  bool _isLoading = true;

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
            content: Text('Falha ao atualizar as configurações de notificação.'),
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
                    child: Text('Você ainda não se juntou a nenhuma comunidade.'),
                  ),
                ..._userGroups.map((g) {
                  final isMuted = _mutedGroups.contains(g['id']);
                  return SwitchListTile(
                    title: Text(g['name']),
                    subtitle: Text(
                      isMuted ? 'Notificações desligadas' : 'Notificações ligadas',
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
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Tem certeza de que deseja sair??'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Logout',
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
