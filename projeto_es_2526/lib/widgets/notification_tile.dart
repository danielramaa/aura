import 'package:flutter/material.dart';

class NotificationTile extends StatelessWidget {
  final String description;
  final String timeString;
  final String type;
  final bool isRead;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.description,
    required this.timeString,
    required this.type,
    required this.isRead,
    required this.onTap,
  });

  IconData get _typeIcon => switch (type) {
    'message' => Icons.message,
    'reaction' => Icons.favorite,
    _ => Icons.notifications,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead ? Colors.white : Colors.blue[50]?.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_typeIcon, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
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
            ],
          ],
        ),
      ),
    );
  }
}
