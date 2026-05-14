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
                      'Sobre a comunidade',
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
                          backgroundColor:
                              isJoined ? Colors.green : const Color(0xFF185FA5),
                          disabledBackgroundColor:
                              isJoined ? Colors.green : Colors.grey[300],
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
              onChanged: (q) => setState(() => _searchQuery = q),
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
            child: StreamBuilder<List<Group>>(
              stream: _groupsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Failed to load groups.'),
                  );
                }

                final query = _searchQuery.toLowerCase();
                final groups = (snapshot.data ?? []).where((g) {
                  if (query.isEmpty) return true;
                  return g.name.toLowerCase().contains(query) ||
                      g.description.toLowerCase().contains(query);
                }).toList();

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.group_outlined
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No communities yet'
                              : 'No communities found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Communities will appear here once created.'
                              : 'Try a different search term.',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final isJoined = _joinedIds.contains(group.id);
                    return InkWell(
                      onTap: () => _showCommunityPreview(group),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${group.memberCount} members',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    group.description,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isJoined)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
