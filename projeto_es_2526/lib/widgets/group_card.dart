import 'package:flutter/material.dart';

class GroupCard extends StatelessWidget {
  final String name;
  final String? lastMessage;
  final String? time;
  final Color color;
  final int unreadCount;
  final bool isOnline;
  final int memberCount;

  const GroupCard({
    super.key,
    required this.name,
    required this.color,
    this.lastMessage,
    this.time,
    this.unreadCount = 0,
    this.isOnline = false,
    this.memberCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  if (lastMessage != null) ...[
                    SizedBox(height: 4),
                    Text(
                      lastMessage!,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline
                              ? Color(0xFF1D9E75)
                              : Colors.grey[400],
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        isOnline ? 'Online agora' : 'Ninguém online',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                      if (memberCount > 0) ...[
                        SizedBox(width: 8),
                        Text(
                          '$memberCount membros',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (time != null)
                  Text(
                    time!,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                SizedBox(height: 6),
                if (unreadCount > 0)
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF185FA5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
