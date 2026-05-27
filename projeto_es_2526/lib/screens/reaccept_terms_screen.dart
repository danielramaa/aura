import 'package:flutter/material.dart';
import '../models/legal_document.dart';
import '../widgets/legal_document_dialog.dart';

/// Blocking screen shown to an authenticated user whose stored acceptance is
/// older than the current document versions. The user must accept to continue
/// or decline, which logs them out (issue #24, scenarios A3/B3).
class ReacceptTermsScreen extends StatefulWidget {
  /// Called when the user accepts; should persist the new acceptance.
  final Future<void> Function() onAccept;

  /// Called when the user declines; should log the user out.
  final Future<void> Function() onDecline;

  const ReacceptTermsScreen({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<ReacceptTermsScreen> createState() => _ReacceptTermsScreenState();
}

class _ReacceptTermsScreenState extends State<ReacceptTermsScreen> {
  static const _blue = Color(0xFF185FA5);

  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      debugPrint('ReacceptTermsScreen action failed: $e');
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível concluir. Verifique a sua ligação e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.gavel, size: 48, color: _blue),
                  const SizedBox(height: 16),
                  Text(
                    'Atualizámos os nossos termos',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Para continuar a utilizar a aplicação, precisa de rever e '
                    'aceitar a versão atual dos Termos e Condições e da Política '
                    'de Privacidade.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => LegalDocumentDialog.show(
                            context,
                            LegalDocuments.terms,
                          ),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Termos e Condições'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => LegalDocumentDialog.show(
                            context,
                            LegalDocuments.privacyPolicy,
                          ),
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Política de Privacidade'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : () => _run(widget.onAccept),
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Aceito'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => _run(widget.onDecline),
                    child: const Text('Recuso e termino sessão'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
