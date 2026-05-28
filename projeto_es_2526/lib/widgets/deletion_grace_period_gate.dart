import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/gdpr_service.dart';

class DeletionGracePeriodGate extends StatefulWidget {
  final String userId;
  final Widget child;
  final GDPRService? gdprService;
  final AuthService? authService;

  const DeletionGracePeriodGate({
    super.key,
    required this.userId,
    required this.child,
    this.gdprService,
    this.authService,
  });

  @override
  State<DeletionGracePeriodGate> createState() =>
      _DeletionGracePeriodGateState();
}

class _DeletionGracePeriodGateState extends State<DeletionGracePeriodGate> {
  late final GDPRService _gdprService = widget.gdprService ?? GDPRService();
  late final AuthService _authService = widget.authService ?? AuthService();

  late Future<DateTime?> _deletionDateFuture;
  bool _isReactivating = false;
  bool _deletionStarted = false;

  @override
  void initState() {
    super.initState();
    _deletionDateFuture = _gdprService.getScheduledDeletionDate(widget.userId);
  }

  @override
  void didUpdateWidget(covariant DeletionGracePeriodGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _deletionStarted = false;
      setState(() {
        _deletionDateFuture = _gdprService.getScheduledDeletionDate(
          widget.userId,
        );
      });
    }
  }

  Future<void> _cancelDeletion() async {
    setState(() => _isReactivating = true);
    try {
      await _gdprService.cancelAccountDeletion(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A sua conta foi reativada com sucesso! Bem-vindo de volta.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _deletionDateFuture = Future.value(null);
          _isReactivating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isReactivating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erro ao reativar a conta. Tente novamente mais tarde.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
  }

  /// Runs the permanent erasure once, after the grace period has expired. The
  /// resulting Auth account deletion makes the auth stream emit null, which
  /// returns the user to the login screen.
  void _runDeletionIfNeeded() {
    if (_deletionStarted) return;
    _deletionStarted = true;
    () async {
      try {
        await _gdprService.executeAccountDeletion(widget.userId);
      } finally {
        // Ensure the session ends even if the Auth deletion was deferred.
        await _authService.logout();
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DateTime?>(
      future: _deletionDateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final deletionDate = snapshot.data;

        // Not scheduled (or the check failed — fail open so a transient error
        // can't lock an authenticated user out).
        if (deletionDate == null) {
          return widget.child;
        }

        // Grace period elapsed: erase the account now.
        if (!DateTime.now().isBefore(deletionDate)) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _runDeletionIfNeeded(),
          );
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(
                    'A eliminar a sua conta de forma definitiva...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Still within the grace period: offer reactivation.
        return _buildReactivationScreen(deletionDate);
      },
    );
  }

  Widget _buildReactivationScreen(DateTime deletionDate) {
    final daysLeft = deletionDate.difference(DateTime.now()).inDays;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.settings_backup_restore_rounded,
                  size: 80,
                  color: Color(0xFF185FA5),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Reativação de Conta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'A sua conta está agendada para ser eliminada de forma definitiva '
                  'dentro de $daysLeft dia(s).\n\nDeseja cancelar o processo de '
                  'eliminação e reativar o seu acesso imediato?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                if (_isReactivating)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF185FA5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _cancelDeletion,
                    child: const Text(
                      'Restaurar e Ativar Conta',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _logout,
                    child: Text(
                      'Sair (Logout)',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
