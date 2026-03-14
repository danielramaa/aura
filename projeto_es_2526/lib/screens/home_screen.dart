import 'package:flutter/material.dart';
import '../widgets/group_card.dart';

class HomeScreen extends StatelessWidget {
  HomeScreen({super.key});
  final List<Map<String, dynamic>> groups = [
    {
      'name': 'Diabetes Tipo 2',
      'lastMessage': 'User123: "Olá!"',
      'time': '14:32',
      'color': Color(0xFF1D9E75),
    },
    {
      'name': 'Hipertensão',
      'lastMessage': 'Anonymous: "Alguém tem dicas para controlar a pressão?"',
      'time': '11:05',
      'color': Color(0xFF378ADD),
    },
    {
      'name': 'Asma',
      'lastMessage': 'Sem novas mensagens',
      'time': 'Mon',
      'color': Color(0xFFD4537E),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                        '3 active groups',
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
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: groups.length,
                separatorBuilder: (context, index) => SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return GroupCard(
                    name: group['name'],
                    lastMessage: group['lastMessage'],
                    time: group['time'],
                    color: group['color'],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
