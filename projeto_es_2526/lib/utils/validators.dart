final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Insira o seu e-mail';
  if (!_emailRegex.hasMatch(email)) return 'Insira um endereço de e-mail válido.';
  return null;
}
