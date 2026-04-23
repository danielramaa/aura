import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  void _openChat(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    if (data['isRead'] != true) {
      await FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({
        'isRead': true,
      });
    }

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          groupId: data['groupId'] ?? '',
          groupName: data['groupName'] ?? 'Community',
          memberCount: '150',
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
          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No new notifications',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('senderId', isNotEqualTo: FirebaseAuth.instance.currentUser?.uid)
            .orderBy('senderId') 
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              
              final isRead = data['isRead'] ?? false;
              
              String timeString = 'Now';
              if (data['timestamp'] != null) {
                 final Timestamp timestamp = data['timestamp'] as Timestamp;
                 final DateTime dateTime = timestamp.toDate();
                 timeString = timeago.format(dateTime, locale: 'en'); 
              }

              return InkWell(
                onTap: () => _openChat(context, doc),
                child: Container(
                  color: isRead ? Colors.white : Colors.blue[50]?..withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue..withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.message, color: Colors.blue, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['description'] ?? 'New notification',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              timeString,
                              style: TextStyle(
                                fontSize: 12,
                                color: isRead ? Colors.grey[500] : Colors.blue[600],
                                fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF185FA5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ]
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