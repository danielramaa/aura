final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email';
  if (!_emailRegex.hasMatch(email)) return 'Enter a valid email address';
  return null;
}
