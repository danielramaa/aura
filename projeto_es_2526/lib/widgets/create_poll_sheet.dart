import 'package:flutter/material.dart';

class CreatePollSheet extends StatefulWidget {
  /// Called with (question, optionTexts) when the user taps Publish.
  /// Return an error string to show a snackbar, or null on success.
  final Future<String?> Function(String question, List<String> options)
  onPublish;

  const CreatePollSheet({super.key, required this.onPublish});

  @override
  State<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends State<CreatePollSheet> {
  static const int _minOptions = 2;
  static const int _maxOptions = 6;

  final _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];

  String? _questionError;
  final List<String?> _optionErrors = [null, null];

  bool _isPublishing = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionCtrls.length >= _maxOptions) return;
    setState(() {
      _optionCtrls.add(TextEditingController());
      _optionErrors.add(null);
    });
  }

  void _removeOption(int index) {
    if (_optionCtrls.length <= _minOptions) return;
    setState(() {
      _optionCtrls[index].dispose();
      _optionCtrls.removeAt(index);
      _optionErrors.removeAt(index);
    });
  }

  bool _validate() {
    bool valid = true;
    final question = _questionCtrl.text.trim();

    setState(() {
      _questionError = question.isEmpty ? 'Question cannot be empty.' : null;
      if (_questionError != null) valid = false;

      for (int i = 0; i < _optionCtrls.length; i++) {
        if (_optionCtrls[i].text.trim().isEmpty) {
          _optionErrors[i] = 'Option cannot be empty.';
          valid = false;
        } else {
          _optionErrors[i] = null;
        }
      }
    });

    return valid;
  }

  Future<void> _publish() async {
    if (!_validate()) return;

    setState(() => _isPublishing = true);

    final error = await widget.onPublish(
      _questionCtrl.text.trim(),
      _optionCtrls.map((c) => c.text.trim()).toList(),
    );

    if (!mounted) return;
    setState(() => _isPublishing = false);

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAddOption = _optionCtrls.length < _maxOptions;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Column(
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Create Poll',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  TextField(
                    controller: _questionCtrl,
                    maxLength: 200,
                    maxLines: 2,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Question',
                      hintText: 'Ask something…',
                      errorText: _questionError,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      if (_questionError != null) {
                        setState(() => _questionError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Options',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_optionCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _optionCtrls[i],
                              maxLength: 100,
                              textInputAction:
                                  i < _optionCtrls.length - 1
                                      ? TextInputAction.next
                                      : TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: 'Option ${i + 1}',
                                errorText: _optionErrors[i],
                                border: const OutlineInputBorder(),
                                counterText: '',
                              ),
                              onChanged: (_) {
                                if (_optionErrors[i] != null) {
                                  setState(() => _optionErrors[i] = null);
                                }
                              },
                            ),
                          ),
                          if (_optionCtrls.length > _minOptions) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              color: theme.colorScheme.error,
                              tooltip: 'Remove option',
                              onPressed: () => _removeOption(i),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  if (canAddOption)
                    TextButton.icon(
                      onPressed: _addOption,
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Add option (${_optionCtrls.length}/$_maxOptions)',
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isPublishing ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isPublishing ? null : _publish,
                      child: _isPublishing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Publish Poll'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
