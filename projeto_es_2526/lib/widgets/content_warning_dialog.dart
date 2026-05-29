import 'package:flutter/material.dart';
import '../services/content_filtering_service.dart';

class ContentWarningDialog extends StatelessWidget {
  final FilteringResult result;

  const ContentWarningDialog({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final flaggedTerms = result.flaggedTerms;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.amber,
            size: 28,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Aviso de Conteúdo',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A sua mensagem contém termos que violam as nossas diretrizes de comunidade para manter um ambiente respeitoso e seguro.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            const Text(
              'Termos detetados:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ...flaggedTerms.map((term) {
              final isHateSpeech = term.category.contains('ódio');
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  children: [
                    Icon(
                      isHateSpeech ? Icons.gavel_rounded : Icons.forum_rounded,
                      size: 16,
                      color: isHateSpeech ? Colors.red : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                          children: [
                            TextSpan(
                              text: '"${ContentFilteringService.maskWord(term.word)}"',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: ' classificado como ',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            TextSpan(
                              text: term.category,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isHateSpeech ? Colors.red[700] : Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visualização da mensagem censurada:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.filteredText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Reescrever',
            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF185FA5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Enviar Censurada',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
