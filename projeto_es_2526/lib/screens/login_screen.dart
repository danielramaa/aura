import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../models/legal_document.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/legal_document_dialog.dart';
import 'forgot_password.dart';

class LoginScreen extends StatefulWidget {
  final AuthService? authService;

  const LoginScreen({super.key, this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  late final _authService = widget.authService ?? AuthService();
  late final _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegalDocument(LegalDocuments.terms);
  late final _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => _openLegalDocument(LegalDocuments.privacyPolicy);

  bool _isLogin = true;
  bool _stayLoggedIn = true;
  bool _acceptedTerms = false;
  bool _loading = false;
  String? _errorMessage;
  String _password = '';
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(
      () => setState(() => _password = _passwordController.text),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _dateOfBirthController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  ({String label, Color color}) _passwordStrength(String p) {
    if (p.isEmpty) return (label: '', color: Colors.transparent);
    int score = 0;
    if (p.length >= 8) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    if (score <= 1) return (label: 'Weak', color: Colors.red);
    if (score <= 2) return (label: 'Medium', color: Colors.orange);
    return (label: 'Strong', color: Colors.green);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _authService.setStayLoggedIn(_stayLoggedIn);
      if (_isLogin) {
        await _authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await _authService.register(
          _emailController.text.trim(),
          _passwordController.text,
          // Guaranteed non-null: the form validator above requires it.
          dateOfBirth: _dateOfBirth!,
          acceptedTerms: _acceptedTerms,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } on ArgumentError catch (e) {
      setState(() => _errorMessage = e.message?.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 8 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  static const _blue = Color(0xFF185FA5);

  Future<void> _openLegalDocument(LegalDocument document) {
    return LegalDocumentDialog.show(context, document);
  }

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _dateOfBirth ?? DateTime(today.year - 13, today.month, today.day),
      firstDate: DateTime(today.year - 120),
      lastDate: today,
    );

    if (picked == null) return;

    setState(() {
      _dateOfBirth = DateTime(picked.year, picked.month, picked.day);
      _dateOfBirthController.text = _formatDate(_dateOfBirth!);
    });
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(primary: _blue),
      ),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    Text(
                      _isLogin ? 'Welcome back' : 'Create account',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Enter your password';
                        }
                        if (!_isLogin && v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    if (!_isLogin && _password.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final s = _passwordStrength(_password);
                          return Row(
                            children: [
                              Text(
                                'Strength: ${s.label}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: s.color,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (!_isLogin) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dateOfBirthController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Data de nascimento',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: _loading ? null : _pickDateOfBirth,
                        validator: (_) {
                          if (_dateOfBirth == null) {
                            return 'Indique a sua data de nascimento';
                          }
                          if (!isAtLeastMinimumAge(_dateOfBirth!)) {
                            return 'Tem de ter pelo menos 13 anos para criar conta';
                          }
                          return null;
                        },
                      ),
                    ],
                    if (_isLogin) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ForgotPasswordScreen(
                                      authService: _authService,
                                    ),
                                  ),
                                ),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ],
                    if (!_isLogin) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            onChanged: _loading
                                ? null
                                : (value) => setState(
                                    () => _acceptedTerms = value ?? false,
                                  ),
                          ),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Eu li e aceito os '),
                                  TextSpan(
                                    text: 'Termos e Condições',
                                    style: const TextStyle(
                                      color: _blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: _termsRecognizer,
                                  ),
                                  const TextSpan(text: ' e a '),
                                  TextSpan(
                                    text: 'Política de Privacidade',
                                    style: const TextStyle(
                                      color: _blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    recognizer: _privacyRecognizer,
                                  ),
                                  const TextSpan(text: '.'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _stayLoggedIn,
                          onChanged: (v) =>
                              setState(() => _stayLoggedIn = v ?? true),
                        ),
                        const Text('Stay logged in'),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: (_loading || (!_isLogin && !_acceptedTerms))
                          ? null
                          : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isLogin ? 'Login' : 'Register'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                              _isLogin = !_isLogin;
                              _acceptedTerms = false;
                              _dateOfBirth = null;
                              _dateOfBirthController.clear();
                              _errorMessage = null;
                            }),
                      child: Text(
                        _isLogin
                            ? "Don't have an account? Register"
                            : 'Already have an account? Login',
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
