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
  State<DeletionGracePeriodGate> createState() => _DeletionGracePeriodGateState();
}

class _DeletionGracePeriodGateState extends State<DeletionGracePeriodGate> {
  late final GDPRService _gdprService = widget.gdprService ?? GDPRService();
  late final AuthService _authService = widget.authService ?? AuthService();

  late Future<bool> _checkDeletionFuture;
  bool _isReactivating = false;

  @override
  void initState() {
    super.initState();
    _checkDeletionFuture = _gdprService.isAccountDeletionScheduled(widget.userId);
  }

  @override
  void didUpdateWidget(covariant DeletionGracePeriodGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      setState(() {
        _checkDeletionFuture = _gdprService.isAccountDeletionScheduled(widget.userId);
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
            content: Text('A sua conta foi reativada com sucesso! Bem-vindo de volta.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _checkDeletionFuture = Future.value(false);
          _isReactivating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isReactivating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao reativar a conta. Tente novamente mais tarde.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkDeletionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Fail open: if check fails, let them see app.
        if (snapshot.data == true) {
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
                        'A sua conta está atualmente agendada para ser eliminada de forma definitiva (Período de Carência de 30 dias).\n\nDeseja cancelar o processo de eliminação e reativar o seu acesso imediato?',
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

        return widget.child;
      },
    );
  }
}
