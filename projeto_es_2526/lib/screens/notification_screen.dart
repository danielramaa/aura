import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import '../widgets/notification_tile.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<String>? _userGroupIds;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _loadUserGroups();
  }

  Future<void> _loadUserGroups() async {
    try {
      _currentUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      if (mounted) setState(() => _userGroupIds = []);
      return;
    }
    if (_currentUid == null) {
      if (mounted) setState(() => _userGroupIds = []);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('anonymousIdentities')
          .get();
      if (mounted) {
        setState(() {
          // whereIn is limited to 30 values; users in >30 groups will only see
          // notifications for their most recently joined 30.
          _userGroupIds = snap.docs.map((d) => d.id).take(30).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _userGroupIds = []);
    }
  }

  Future<void> _openChat(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    if (data['isRead'] != true) {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(doc.id)
          .update({'isRead': true});
    }

    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(data['groupId'] as String? ?? '')
        .get();
    final memberCount = (groupDoc.data()?['memberCount'] as num?)?.toInt() ?? 0;

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          groupId: data['groupId'] ?? '',
          groupName: data['groupName'] ?? 'Community',
          memberCount: memberCount.toString(),
          groupDescription: data['description'] ?? 'New message in community',
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No new notifications',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userGroupIds == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_userGroupIds!.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: _buildEmptyState(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('groupId', whereIn: _userGroupIds)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('Notification stream error: ${snapshot.error}');
            return _buildEmptyState();
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs =
              snapshot.data?.docs
                  .where(
                    (d) =>
                        (d.data() as Map<String, dynamic>)['senderId'] !=
                        _currentUid,
                  )
                  .toList() ??
              [];

          if (docs.isEmpty) return _buildEmptyState();

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['isRead'] as bool? ?? false;
              final type = data['type'] as String? ?? 'message';

              String timeString = 'Now';
              if (data['timestamp'] != null) {
                final timestamp = data['timestamp'] as Timestamp;
                timeString = timeago.format(timestamp.toDate(), locale: 'en');
              }

              return NotificationTile(
                description: data['description'] ?? 'New notification',
                timeString: timeString,
                type: type,
                isRead: isRead,
                onTap: () => _openChat(context, doc),
              );
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    title: const Text(
      'Notifications',
      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
  );
}
