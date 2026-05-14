import 'package:flutter/material.dart';
import '../controllers/profile_controller.dart';
import '../widgets/edit_profile_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileController? controller;

  const ProfileScreen({super.key, this.controller});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? ProfileController();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Future<void> _showEditProfileDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => EditProfileDialog(controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final user = _controller.currentUser;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            actions: [
              if (user != null)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Profile',
                  onPressed: _showEditProfileDialog,
                ),
            ],
          ),
          body: user == null
              ? const Center(child: Text('User not logged in.'))
              : _buildBody(context, user),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, user) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Color(0xFFDCE9F7),
            child: Icon(Icons.person, size: 50, color: Color(0xFF185FA5)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            user.displayName ?? 'Anonymous User',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            user.email ?? 'No email available',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 32),
        Text('My Communities', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_controller.isLoadingCommunities)
          const Center(child: CircularProgressIndicator())
        else if (_controller.communityError != null)
          Text(
            _controller.communityError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else if (_controller.joinedCommunities.isEmpty)
          const Text('You have not joined any communities yet.')
        else
          ..._controller.joinedCommunities.map(
            (community) => Card(
              child: ListTile(
                leading: const Icon(Icons.group),
                title: Text(community.name),
              ),
            ),
          ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          onPressed: _controller.logout,
        ),
      ],
    );
  }
}
