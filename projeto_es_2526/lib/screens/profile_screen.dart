import 'package:flutter/material.dart';
import '../controllers/profile_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileController _controller = ProfileController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _controller.currentUser?.displayName);
    final photoController = TextEditingController(text: _controller.currentUser?.photoURL);
    final emailController = TextEditingController(text: _controller.currentUser?.email);
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: photoController,
                  decoration: const InputDecoration(labelText: 'Photo URL'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Leave blank to keep current',
                  ),
                  obscureText: true,
                ),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    hintText: 'Leave blank to keep current',
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final password = passwordController.text.trim();
                final confirmPassword = confirmPasswordController.text.trim();

                if (password.isNotEmpty && password != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passwords do not match!')),
                  );
                  return;
                }

                _controller.updateProfile(
                  displayName: nameController.text.trim(),
                  photoURL: photoController.text.trim(),
                  email: emailController.text.trim(),
                  password: password,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileDialog,
          )
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final user = _controller.currentUser;

          if (user == null) {
            return const Center(child: Text('User not logged in.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 1. Avatar, Name and Email
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
                      ? NetworkImage(user.photoURL!)
                      : null,
                  child: (user.photoURL == null || user.photoURL!.isEmpty)
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

              // 2. Communities List
              Text(
                'My Communities',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (_controller.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_controller.joinedCommunities.isEmpty)
                const Text('You have not joined any communities yet.')
              else
                ..._controller.joinedCommunities.map((communityId) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.group),
                      title: Text(
                        communityId
                            .split('-')
                            .map((word) => word.isNotEmpty
                                ? '${word[0].toUpperCase()}${word.substring(1)}'
                                : '')
                            .join(' '),
                      ),
                    ),
                  );
                }).toList(),

              const SizedBox(height: 32),

              // 3. Logout Button
              ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: () => _controller.logout(),
              ),
            ],
          );
        },
      ),
    );
  }
}