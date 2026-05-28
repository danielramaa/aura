import 'package:flutter/material.dart';
import '../controllers/profile_controller.dart';
import '../models/user_role.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/role_badge.dart';
import 'admin_applications_screen.dart';
import 'admin_reports_screen.dart';
import 'settings_screen.dart';

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

  Future<void> _showApplyModeratorDialog() async {
    final formKey = GlobalKey<FormState>();
    String licenseNumber = '';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Apply for Moderator'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'To become a verified moderator, please provide your medical credentials.',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Medical License / Certification',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  onSaved: (v) => licenseNumber = v!.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        formKey.currentState!.save();
                        setDialogState(() => isSubmitting = true);
                        final err = await _controller
                            .submitModeratorApplication(licenseNumber);
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                err ?? 'Application submitted successfully!',
                              ),
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
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
              if (user != null) ...[
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Profile',
                  onPressed: _showEditProfileDialog,
                ),
              ],
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
            backgroundColor: const Color(0xFFDCE9F7),
            backgroundImage: user.photoURL?.isNotEmpty == true
                ? NetworkImage(user.photoURL!)
                : null,
            child: user.photoURL?.isNotEmpty != true
                ? const Icon(Icons.person, size: 50, color: Color(0xFF185FA5))
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: RoleBadge(uid: user.uid)),
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
        if (_controller.userRole == UserRole.admin) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Review Moderator Applications'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminApplicationsScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF185FA5),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.report_gmailerrorred_outlined),
            label: const Text('Denúncias'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminReportsScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF185FA5),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_controller.userRole == UserRole.user) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Apply for Medical Moderator'),
            onPressed: _showApplyModeratorDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF185FA5),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          onPressed: _controller.logout,
        ),
      ],
    );
  }
}
