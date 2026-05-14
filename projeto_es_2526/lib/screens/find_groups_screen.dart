import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group.dart';
import '../services/group_service.dart';
import '../services/identity_service.dart';
import 'chat_screen.dart';

class FindGroupsScreen extends StatefulWidget {
  final GroupService? groupService;
  final IdentityService? identityService;
  final FirebaseAuth? auth;

  const FindGroupsScreen({
    super.key,
    this.groupService,
    this.identityService,
    this.auth,
  });

  @override
  State<FindGroupsScreen> createState() => _FindGroupsScreenState();
}

class _FindGroupsScreenState extends State<FindGroupsScreen> {
  late final GroupService _groupService;
  late final IdentityService _identityService;
  late final FirebaseAuth _auth;
  late final Stream<List<Group>> _groupsStream;

  Set<String> _joinedIds = {};
  StreamSubscription<Set<String>>? _joinedIdsSub;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _retryKey = 0;

  final List<String> _categories = [
    'Mental Health',
    'Autoimmune Diseases',
    'Neurodivergence',
    'Physical Wellness',
    'General'
  ];

  final List<Group> _mockGroups = const [
    Group(
      id: 'ansiedade-e-foco',
      name: 'Ansiedade e Foco',
      color: Colors.blue,
      memberCount: 3500,
      description:
          'Estratégias diárias e meditação para lidar com a ansiedade e melhorar o foco no trabalho e estudos.',
      category: 'Mental Health',
    ),
    Group(
      id: 'vida-com-endometriose',
      name: 'Vida com Endometriose',
      color: Colors.pink,
      memberCount: 1200,
      description:
          'Apoio mútuo, troca de experiências sobre médicos, tratamentos e como lidar com a dor no dia a dia.',
      category: 'Autoimmune Diseases',
    ),
    Group(
      id: 'pais-de-criancas-autistas',
      name: 'Pais de Crianças Autistas',
      color: Colors.orange,
      memberCount: 4800,
      description:
          'Comunidade acolhedora para partilhar vitórias, desafios e recursos sobre o espetro autista.',
      category: 'Neurodivergence',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _groupService = widget.groupService ?? GroupService();
    _identityService = widget.identityService ?? IdentityService();
    _auth = widget.auth ?? FirebaseAuth.instance;
    _groupsStream = _groupService.streamGroups();

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      _joinedIdsSub = _groupService
          .streamJoinedGroups(uid)
          .map((gs) => gs.map((g) => g.id).toSet())
          .listen((ids) {
            if (mounted) setState(() => _joinedIds = ids);
          });
    }
  }

  @override
  void dispose() {
    _joinedIdsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _triggerRetry() {
    setState(() => _retryKey++);
  }

  void _showCommunityPreview(Group group) {
    final scaffoldContext = context;
    final isJoined = _joinedIds.contains(group.id);

    showDialog<void>(
      context: scaffoldContext,
      builder: (dialogContext) {
        bool isJoining = false;
        return StatefulBuilder(
          builder: (_, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
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
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => Navigator.pop(dialogContext),
                          child: const Icon(
                            Icons.close,
                            color: Colors.grey,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${group.memberCount} members',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'About the community',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      group.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: isJoined || isJoining
                            ? null
                            : () async {
                                final uid = _auth.currentUser?.uid;
                                if (uid == null) return;

                                setDialogState(() => isJoining = true);
                                try {
                                  await _identityService.getOrCreateIdentity(
                                    uid,
                                    group.id,
                                  );
                                  if (!scaffoldContext.mounted) return;
                                  Navigator.pop(scaffoldContext);
                                  Navigator.push(
                                    scaffoldContext,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        groupId: group.id,
                                        groupName: group.name,
                                        memberCount:
                                            group.memberCount.toString(),
                                        groupDescription: group.description,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint('Join group error: $e');
                                  if (dialogContext.mounted) {
                                    setDialogState(() => isJoining = false);
                                  }
                                  if (scaffoldContext.mounted) {
                                    ScaffoldMessenger.of(
                                      scaffoldContext,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text('$e'),
                                        duration: const Duration(seconds: 6),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: isJoined
                              ? Colors.green
                              : const Color(0xFF185FA5),
                          disabledBackgroundColor: isJoined
                              ? Colors.green
                              : Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isJoining
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isJoined ? 'Already Joined' : 'Join Community',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
          'Explore',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<Group>>(
        key: ValueKey('groups_stream_$_retryKey'),
        stream: _groupsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No connection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _triggerRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final firebaseGroups = snapshot.data!;
          final Map<String, Group> groupsMap = {
            for (var g in _mockGroups) g.id: g,
          };
          for (var g in firebaseGroups) {
            groupsMap[g.id] = g;
          }
          final allGroups = groupsMap.values.toList();

          final filteredGroups = _searchQuery.isEmpty
              ? allGroups
              : allGroups.where((g) {
                  final q = _searchQuery.toLowerCase();
                  return g.name.toLowerCase().contains(q) ||
                      g.description.toLowerCase().contains(q);
                }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search communities...',
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
                child: _searchQuery.isNotEmpty
                    ? _buildSearchResults(filteredGroups)
                    : _buildCategoryView(allGroups),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryView(List<Group> allGroups) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final categoryGroups =
            allGroups.where((g) => g.category == category).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (categoryGroups.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Center(
                    child: Text(
                      'New rooms coming soon',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categoryGroups.length,
                  itemBuilder: (context, i) {
                    final group = categoryGroups[i];
                    final isJoined = _joinedIds.contains(group.id);
                    return _buildGroupCard(group, isJoined);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSearchResults(List<Group> groups) {
    if (groups.isEmpty) {
      return const Center(child: Text('No communities found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final isJoined = _joinedIds.contains(group.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildGroupCard(group, isJoined, isVertical: true),
        );
      },
    );
  }

  Widget _buildGroupCard(Group group, bool isJoined, {bool isVertical = false}) {
    return GestureDetector(
      onTap: () => _showCommunityPreview(group),
      child: Container(
        width: isVertical ? double.infinity : 260,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: group.color, radius: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    group.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isJoined ? Icons.check_circle : Icons.add_circle_outline,
                    color: isJoined ? Colors.green : const Color(0xFF185FA5),
                  ),
                  tooltip: isJoined ? 'You are in the group' : 'Join',
                  onPressed:
                      isJoined ? null : () => _showCommunityPreview(group),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              group.description,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              '${group.memberCount} members',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
