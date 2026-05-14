import 'package:flutter/material.dart';
import '../controllers/profile_controller.dart';

class EditProfileDialog extends StatefulWidget {
  final ProfileController controller;

  const EditProfileDialog({super.key, required this.controller});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late final TextEditingController _nameCtrl;
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
    _emailCtrl = TextEditingController(text: user?.email);
    _newPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _currentPasswordCtrl = TextEditingController();

    _emailCtrl.addListener(_onSensitiveFieldChanged);
    _newPasswordCtrl.addListener(_onSensitiveFieldChanged);
  }

  void _onSensitiveFieldChanged() {
    final newEmail = _emailCtrl.text.trim();
    final emailChanged =
        newEmail.isNotEmpty &&
        newEmail != (widget.controller.currentUser?.email ?? '');
    final passwordProvided = _newPasswordCtrl.text.isNotEmpty;
    final needs = emailChanged || passwordProvided;
    if (needs != _needsCurrentPassword) {
      setState(() => _needsCurrentPassword = needs);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    setState(() => _isSaving = true);

    final error = await widget.controller.updateProfile(
      displayName: _nameCtrl.text.trim(),
      photoURL: widget.controller.currentUser?.photoURL ?? '',
      email: _emailCtrl.text.trim(),
      newPassword: newPassword,
      currentPassword: _currentPasswordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
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
