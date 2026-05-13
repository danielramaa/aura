import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
import '../widgets/group_card.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  final HomeController controller;
  final VoidCallback onFindGroups;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.onFindGroups,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    setState(() => _isSearching = false);
    _searchController.clear();
    widget.controller.setSearchQuery('');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final groups = widget.controller.groups;
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: _isSearching
                    ? _buildSearchBar()
                    : _buildTitleRow(groups),
              ),
              // card list
              Expanded(
                child: widget.controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : widget.controller.error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.controller.error!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : groups.isEmpty
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
                                _isSearching
                                    ? 'No groups match your search'
                                    : 'No communities yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _isSearching
                                    ? 'Try a different search term.'
                                    : 'Join a community to connect with people who understand what you are going through.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                              if (!_isSearching) ...[
                                SizedBox(height: 24),
                                FilledButton(
                                  onPressed: widget.onFindGroups,
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
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    groupId: group.id,
                                    groupName: group.name,
                                    memberCount: group.memberCount.toString(),
                                    groupDescription: group.description,
                                  ),
                                ),
                              );
                            },
                            child: GroupCard(
                              name: group.name,
                              color: group.color,
                              memberCount: group.memberCount,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitleRow(List groups) {
    return Row(
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
        GestureDetector(
          onTap: _startSearch,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Icon(Icons.search, size: 18, color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search groups...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: const Color(0xFF185FA5)),
              ),
            ),
            onChanged: widget.controller.setSearchQuery,
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _stopSearch,
          child: Icon(Icons.close, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
