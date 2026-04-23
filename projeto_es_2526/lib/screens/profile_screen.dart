import 'package:flutter/material.dart';
import '../controllers/profile_controller.dart';

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
      builder: (_) => _EditProfileDialog(controller: _controller),
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
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: user.photoURL?.isNotEmpty == true
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: user.photoURL?.isNotEmpty != true
                      ? const Icon(Icons.person, size: 50)
                      : null,
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'My Communities',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_controller.isLoadingCommunities)
                const Center(child: CircularProgressIndicator())
              else if (_controller.communityError != null)
                Text(
                  _controller.communityError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
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

class _EditProfileDialog extends StatefulWidget {
  final ProfileController controller;

  const _EditProfileDialog({required this.controller});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _photoCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _newPasswordCtrl;
  late final TextEditingController _confirmPasswordCtrl;
  late final TextEditingController _currentPasswordCtrl;

  bool _isSaving = false;
  bool _needsCurrentPassword = false;

  @override
  void initState() {
    super.initState();
    final user = widget.controller.currentUser;
    _nameCtrl = TextEditingController(text: user?.displayName);
    _photoCtrl = TextEditingController(text: user?.photoURL);
    _emailCtrl = TextEditingController(text: user?.email);
    _newPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _currentPasswordCtrl = TextEditingController();

    _emailCtrl.addListener(_onSensitiveFieldChanged);
    _newPasswordCtrl.addListener(_onSensitiveFieldChanged);
  }

  void _onSensitiveFieldChanged() {
    final emailChanged =
        _emailCtrl.text.trim() != (widget.controller.currentUser?.email ?? '');
    final passwordProvided = _newPasswordCtrl.text.isNotEmpty;
    final needs = emailChanged || passwordProvided;
    if (needs != _needsCurrentPassword) {
      setState(() => _needsCurrentPassword = needs);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _photoCtrl.dispose();
    _emailCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _currentPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPassword = _newPasswordCtrl.text.trim();
    final confirmPassword = _confirmPasswordCtrl.text.trim();

    if (newPassword.isNotEmpty && newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final error = await widget.controller.updateProfile(
      displayName: _nameCtrl.text.trim(),
      photoURL: _photoCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      newPassword: newPassword,
      currentPassword: _currentPasswordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _photoCtrl,
              decoration: const InputDecoration(labelText: 'Photo URL'),
            ),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _newPasswordCtrl,
              decoration: const InputDecoration(
                labelText: 'New Password',
                hintText: 'Leave blank to keep current',
              ),
              obscureText: true,
            ),
            TextField(
              controller: _confirmPasswordCtrl,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
              ),
              obscureText: true,
            ),
            if (_needsCurrentPassword)
              TextField(
                controller: _currentPasswordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                  helperText: 'Required to change email or password.',
                ),
                obscureText: true,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
