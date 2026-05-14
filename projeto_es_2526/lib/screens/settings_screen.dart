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

  List<String> _mutedGroups = [];
  List<Map<String, dynamic>> _userGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      _mutedGroups = List<String>.from(data['mutedGroups'] ?? []);
    }

    final identitiesSnap = await _firestore
        .collection('anonymousIdentities')
        .where('userId', isEqualTo: user.uid)
        .get();

    final groupIds = identitiesSnap.docs
        .map((doc) => doc.data()['communityId'])
        .whereType<String>()
        .toSet() 
        .toList();

    final List<Map<String, dynamic>> groupsData = [];
    for (final gid in groupIds) {
      final gDoc = await _firestore.collection('groups').doc(gid).get();
      if (gDoc.exists) {
        groupsData.add({
          'id': gDoc.id,
          'name': gDoc.data()?['name'] ?? 'Unknown',
        });
      }
    }

    if (mounted) {
      setState(() {
        _userGroups = groupsData;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleMute(String groupId, bool isMuted) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      if (isMuted) {
        _mutedGroups.add(groupId);
      } else {
        _mutedGroups.remove(groupId);
      }
    });

    await _firestore.collection('users').doc(user.uid).set({
      'mutedGroups': _mutedGroups,
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Settings',
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
                    'Notification Preferences',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_userGroups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('You have not joined any communities yet.'),
                  ),
                ..._userGroups.map((g) {
                  final isMuted = _mutedGroups.contains(g['id']);
                  return SwitchListTile(
                    title: Text(g['name']),
                    subtitle: Text(isMuted ? 'Notifications off' : 'Notifications on'),
                    value: !isMuted,
                    activeThumbColor: const Color(0xFF185FA5),
                    activeTrackColor: const Color(0xFF185FA5).withValues(alpha: 0.5),
                    onChanged: (val) => _toggleMute(g['id'], !val),
                  );
                }),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Logout', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await AuthService().logout();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    }
                  },
                ),
              ],
            ),
    );
  }
}