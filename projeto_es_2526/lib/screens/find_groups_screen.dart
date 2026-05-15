import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/group.dart';
import '../services/group_service.dart';
import '../services/identity_service.dart';
import '../widgets/category_chip.dart';
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
  late Stream<List<Group>> _groupsStream;

  Set<String> _joinedIds = {};
  StreamSubscription<Set<String>>? _joinedIdsSub;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  int _retryKey = 0;

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
    setState(() {
      _retryKey++;
      _groupsStream = _groupService.streamGroups();
    });
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
                        '${group.memberCount} membros',
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
                                isJoined ? 'Já seguido' : 'Entrar na comunidade',
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
          'Explorar',
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
                    'Sem ligação',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _triggerRetry,
                    child: const Text('Tentar novamente'),
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
            for (var g in GroupService.defaultGroups) g.id: g,
          };
          for (var g in firebaseGroups) {
            groupsMap[g.id] = g;
          }
          final allGroups = groupsMap.values.toList();

          final q = _searchQuery.toLowerCase();
          final filtered = allGroups.where((g) {
            final matchesSearch = q.isEmpty ||
                g.name.toLowerCase().contains(q) ||
                g.description.toLowerCase().contains(q);
            final matchesCategory = _selectedCategory == null ||
                g.category == _selectedCategory;
            return matchesSearch && matchesCategory;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar comunidades...',
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
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Center(
                      child: CategoryChip(
                        label: 'Todas',
                        selected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                    ),
                    for (final cat in GroupService.categories)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Center(
                          child: CategoryChip(
                            label: cat,
                            selected: _selectedCategory == cat,
                            onTap: () => setState(
                              () => _selectedCategory =
                                  _selectedCategory == cat ? null : cat,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty && _selectedCategory != null
                              ? 'Novas salas em breve'
                              : 'Nenhuma comunidade encontrada.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontStyle: _searchQuery.isEmpty &&
                                    _selectedCategory != null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final group = filtered[i];
                          final isJoined = _joinedIds.contains(group.id);
                          return InkWell(
                            onTap: () => _showCommunityPreview(group),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: group.color,
                                    radius: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${group.memberCount} membros',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
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
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Já seguido',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

