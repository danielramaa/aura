import 'package:flutter/material.dart';
import '../models/legal_document.dart';

class LegalDocumentDialog extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentDialog({super.key, required this.document});

  static Future<void> show(BuildContext context, LegalDocument document) {
    return showDialog<void>(
      context: context,
      builder: (_) => LegalDocumentDialog(document: document),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(document.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version ${document.version}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 12),
              Text(document.content),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
