import 'package:flutter/material.dart';
import '../widgets/group_card.dart';

class Group {
  final String name;
  final String lastMessage;
  final String time;
  final Color color;
  final int unreadCount;
  final bool isOnline;
  final int memberCount;

  const Group({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.color,
    required this.unreadCount,
    required this.isOnline,
    required this.memberCount,
  });
}

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key, required this.onFindGroups});
  static const Color defaultGroupColor = Color(0xFF378ADD);
  final VoidCallback onFindGroups;

  static const List<Group> groups = <Group>[ // empty list IF wanna test empty state
    Group(
      name: 'Diabetes Tipo 2',
      lastMessage: 'User123: "Olá!"',
      time: '14:32',
      color: defaultGroupColor,
      unreadCount: 2,
      isOnline: true,
      memberCount: 2400,
    ),
    Group(
      name: 'Hipertensão',
      lastMessage: 'Anonymous: "Alguém tem dicas para controlar a pressão?"',
      time: '11:05',
      color: defaultGroupColor,
      unreadCount: 0,
      isOnline: false,
      memberCount: 1100,
    ),
    Group(
      name: 'Asma',
      lastMessage: 'Sem novas mensagens',
      time: 'Mon',
      color: defaultGroupColor,
      unreadCount: 5,
      isOnline: false,
      memberCount: 890,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Groups',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        groups.isEmpty
                            ? 'No active groups'
                            : '${groups.length} active group${groups.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // card
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No communities yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Join a community to connect with people who understand what you are going through.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                            SizedBox(height: 24),
                            FilledButton(
                              onPressed: onFindGroups,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                backgroundColor: const Color(0xFF185FA5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Find a community',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: groups.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return GroupCard(
                          name: group.name,
                          lastMessage: group.lastMessage,
                          time: group.time,
                          color: group.color,
                          unreadCount: group.unreadCount,
                          isOnline: group.isOnline,
                          memberCount: group.memberCount,
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }
}
