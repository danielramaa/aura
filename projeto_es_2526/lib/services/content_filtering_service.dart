import 'package:cloud_firestore/cloud_firestore.dart';

class FlaggedTerm {
  final String word;
  final String category; // 'profanidade' or 'discurso de ódio'

  const FlaggedTerm({required this.word, required this.category});
}

class FilteringResult {
  final bool isFlagged;
  final String originalText;
  final String filteredText;
  final List<FlaggedTerm> flaggedTerms;

  const FilteringResult({
    required this.isFlagged,
    required this.originalText,
    required this.filteredText,
    required this.flaggedTerms,
  });
}

class ContentFilteringService {
  final FirebaseFirestore _firestore;

  // Default fallback words (normalized to lowercase, no accents)
  static const List<String> defaultProfanities = [
    'puta',
    'merda',
    'caralho',
    'foder',
    'cabrao',
    'fuck',
    'shit',
    'asshole',
    'bitch',
    'cunt',
  ];

  static const List<String> defaultHateSpeech = [
    'paneleiro',
  ];

  List<String> _profanities = List.from(defaultProfanities);
  List<String> _hateSpeech = List.from(defaultHateSpeech);

  ContentFilteringService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _listenToModerationRules();
  }

  void _listenToModerationRules() {
    _firestore.collection('moderation').doc('banned_words').snapshots().listen((snap) {
      if (snap.exists) {
        final data = snap.data() ?? {};
        if (data['profanity'] is List) {
          _profanities = (data['profanity'] as List)
              .map((e) => removeAccents(e.toString().trim()))
              .where((e) => e.isNotEmpty)
              .toList();
        }
        if (data['hateSpeech'] is List) {
          _hateSpeech = (data['hateSpeech'] as List)
              .map((e) => removeAccents(e.toString().trim()))
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }, onError: (e) {
      // Fallback silently to defaults if document doesn't exist yet or permission denied
    });
  }

  // Exposed for tests or manual configuration
  void updateLists({List<String>? profanities, List<String>? hateSpeech}) {
    if (profanities != null) {
      _profanities = profanities.map((e) => removeAccents(e)).toList();
    }
    if (hateSpeech != null) {
      _hateSpeech = hateSpeech.map((e) => removeAccents(e)).toList();
    }
  }

  static String removeAccents(String text) {
    const withRound = 'àáâãäåèéêëìíîïòóôõöùúûüçñý';
    const withoutRound = 'aaaaaaeeeeiiiiooooouuuucny';
    String result = text.toLowerCase();
    for (int i = 0; i < withRound.length; i++) {
      result = result.replaceAll(withRound[i], withoutRound[i]);
    }
    return result;
  }

  static RegExp buildRegexForWord(String word) {
    final Map<String, String> charMap = {
      'a': '[aA4@âãáàä]',
      'b': '[bB8]',
      'c': '[cCçÇ]',
      'd': '[dD]',
      'e': '[eE3êéèë]',
      'f': '[fF]',
      'g': '[gG69]',
      'h': '[hH]',
      'i': '[iI1!|íìïî]',
      'j': '[jJ]',
      'k': '[kK]',
      'l': '[lL1|]',
      'm': '[mM]',
      'n': '[nN]',
      'o': '[oO0ôõóòö]',
      'p': '[pP]',
      'q': '[qQ]',
      'r': '[rR]',
      's': '[sS5\$§]',
      't': '[tT7]',
      'u': '[uUvVüûúù]',
      'v': '[vVuU]',
      'w': '[wW]',
      'x': '[xX%]',
      'y': '[yY]',
      'z': '[zZ2]',
    };

    final buffer = StringBuffer();
    buffer.write(r'\b');
    for (int i = 0; i < word.length; i++) {
      final char = word[i].toLowerCase();
      final pattern = charMap[char] ?? RegExp.escape(char);
      buffer.write(pattern);
      if (i < word.length - 1) {
        buffer.write(r'[\s\.\-\_\*]*');
      }
    }
    buffer.write(r'\b');
    return RegExp(buffer.toString(), caseSensitive: false);
  }

  FilteringResult filterContent(String text) {
    if (text.trim().isEmpty) {
      return FilteringResult(
        isFlagged: false,
        originalText: text,
        filteredText: text,
        flaggedTerms: [],
      );
    }

    String filtered = text;
    final flagged = <FlaggedTerm>[];

    // Combine lists to search
    final allTerms = [
      ..._hateSpeech.map((w) => MapEntry(w, 'discurso de ódio')),
      ..._profanities.map((w) => MapEntry(w, 'profanidade')),
    ];

    for (final entry in allTerms) {
      final word = entry.key;
      final category = entry.value;
      final regex = buildRegexForWord(word);

      // Check if it matches in the CURRENT filtered text
      if (regex.hasMatch(filtered)) {
        final matches = regex.allMatches(filtered).toList();
        if (matches.isNotEmpty) {
          flagged.add(FlaggedTerm(word: word, category: category));
          
          // Replace from right to left so indices don't shift
          for (final match in matches.reversed) {
            final matchedStr = filtered.substring(match.start, match.end);
            final masked = _maskWord(matchedStr);
            filtered = filtered.replaceRange(match.start, match.end, masked);
          }
        }
      }
    }

    return FilteringResult(
      isFlagged: flagged.isNotEmpty,
      originalText: text,
      filteredText: filtered,
      flaggedTerms: flagged,
    );
  }

  String _maskWord(String matched) {
    if (matched.length <= 3) {
      return '*' * matched.length;
    }
    return matched[0] + ('*' * (matched.length - 2)) + matched[matched.length - 1];
  }
}
