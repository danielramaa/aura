import 'package:flutter/material.dart';
import '../models/group.dart'; 
class FindGroupsScreen extends StatefulWidget {
  const FindGroupsScreen({super.key});

  @override
  State<FindGroupsScreen> createState() => _FindGroupsScreenState();
}

class _FindGroupsScreenState extends State<FindGroupsScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  final List<Group> _allCommunities = const [
    Group(
      name: 'Ansiedade e Foco',
      lastMessage: '', time: '', color: Colors.blue, unreadCount: 0, isOnline: false,
      memberCount: 3500,
      description: 'Estratégias diárias e meditação para lidar com a ansiedade e melhorar o foco no trabalho e estudos.',
    ),
    Group(
      name: 'Vida com Endometriose',
      lastMessage: '', time: '', color: Colors.pink, unreadCount: 0, isOnline: false,
      memberCount: 1200,
      description: 'Apoio mútuo, troca de experiências sobre médicos, tratamentos e como lidar com a dor no dia a dia.',
    ),
    Group(
      name: 'Pais de Crianças Autistas',
      lastMessage: '', time: '', color: Colors.orange, unreadCount: 0, isOnline: false,
      memberCount: 4800,
      description: 'Comunidade acolhedora para partilhar vitórias, desafios e recursos sobre o espetro autista.',
    ),
  ];

  List<Group> _filteredCommunities = [];

  @override
  void initState() {
    super.initState();
    _filteredCommunities = _allCommunities;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCommunities(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCommunities = _allCommunities;
      } else {
        _filteredCommunities = _allCommunities.where((group) {
          final nameLower = group.name.toLowerCase();
          final descLower = group.description.toLowerCase();
          final searchLower = query.toLowerCase();
          return nameLower.contains(searchLower) || descLower.contains(searchLower);
        }).toList();
      }
    });
  }

  void _showCommunityPreview(Group group) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24), 
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32.0), 
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.grey, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${group.memberCount} members',
                    style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 32),
                
                const Text(
                  'Sobre a comunidade',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  group.description,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5),
                ),
                const SizedBox(height: 48), 
                
                SizedBox(
                  width: double.infinity,
                  height: 56, 
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context); 
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Bem-vinda ao grupo ${group.name}!')),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF185FA5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Join Community', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          'Find Groups',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCommunities,
              decoration: InputDecoration(
                hintText: 'Search by name or condition...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: _filteredCommunities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No communities found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term.',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  )
                // 2. Lista de Comunidades (temos que adicionar mais)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCommunities.length,
                    separatorBuilder: (context, index) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final group = _filteredCommunities[index];
                      return InkWell(
                        onTap: () => _showCommunityPreview(group),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${group.memberCount} members',
                                style: TextStyle(fontSize: 12, color: Colors.blue[600], fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                group.description,
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
