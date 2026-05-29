import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/services/content_filtering_service.dart';

void main() {
  group('ContentFilteringService Tests', () {
    late ContentFilteringService filterService;

    setUp(() {
      filterService = ContentFilteringService(
        firestore: FakeFirebaseFirestore(),
      );
      // Configure custom lists for test predictability
      filterService.updateLists(
        profanities: ['puta', 'merda', 'fuck', 'shit'],
        hateSpeech: ['paneleiro'],
      );
    });

    test('Identifies standard profanity and masks it', () {
      final result = filterService.filterContent('Isto é uma merda!');
      expect(result.isFlagged, isTrue);
      expect(result.filteredText, 'Isto é uma m***a!');
      expect(result.flaggedTerms.length, 1);
      expect(result.flaggedTerms.first.word, 'merda');
      expect(result.flaggedTerms.first.category, 'profanidade');
    });

    test('Identifies standard hate speech and masks it', () {
      final result = filterService.filterContent('Aquele gajo é um paneleiro.');
      expect(result.isFlagged, isTrue);
      expect(result.filteredText, 'Aquele gajo é um p*******o.');
      expect(result.flaggedTerms.length, 1);
      expect(result.flaggedTerms.first.word, 'paneleiro');
      expect(result.flaggedTerms.first.category, 'discurso de ódio');
    });

    test('Handles case-insensitivity', () {
      final result = filterService.filterContent('MerdA total');
      expect(result.isFlagged, isTrue);
      expect(result.filteredText, 'M***A total');
    });

    test('Detects variation: dots/separators', () {
      final result = filterService.filterContent('p.u.t.a que pariu');
      expect(result.isFlagged, isTrue);
      expect(result.filteredText, 'p*****a que pariu');
    });

    test('Detects variation: spaces', () {
      final result = filterService.filterContent('ele é um f u c k');
      expect(result.isFlagged, isTrue);
      expect(result.filteredText, 'ele é um f*****k');
    });

    test('Detects variation: leetspeak', () {
      // 'p' -> p, 'u' -> v, 't' -> 7, 'a' -> 4
      final result = filterService.filterContent('seu p v 7 4');
      expect(result.isFlagged, isTrue);
      expect(result.filteredText, 'seu p*****4');
    });

    test('Detects variation: accents and diacritics', () {
      // Add 'cabrão' to tests
      filterService.updateLists(profanities: ['cabrão']);
      final result = filterService.filterContent('Que cabrão!');
      expect(result.isFlagged, isTrue);
      expect(result.filteredText, 'Que c****o!');
    });

    test('Avoids false positives (sub-string match without word boundary)', () {
      final result = filterService.filterContent('Vou computar o resultado');
      expect(result.isFlagged, isFalse);
      expect(result.filteredText, 'Vou computar o resultado');
    });

    test('Handles multiple occurrences', () {
      final result = filterService.filterContent('merda e mais merda');
      expect(result.isFlagged, isTrue);
      expect(result.filteredText, 'm***a e mais m***a');
      expect(result.flaggedTerms.length, 1); // unique words flagged
    });

    test('Fully masks short (<=4 char) slurs so they are not legible', () {
      final result = filterService.filterContent('isto é fuck');
      expect(result.isFlagged, isTrue);
      expect(result.filteredText, 'isto é ****');
    });

    test('Does not match across an unbounded run of separators', () {
      // More than two separators between letters is no longer treated as the
      // same word, avoiding false positives spread across unrelated words.
      final result = filterService.filterContent('f     u     c     k');
      expect(result.isFlagged, isFalse);
      expect(result.filteredText, 'f     u     c     k');
    });

    test('maskWord censors a term for display', () {
      expect(ContentFilteringService.maskWord('puta'), '****');
      expect(ContentFilteringService.maskWord('paneleiro'), 'p*******o');
    });

    test('Handles mixed categories', () {
      final result = filterService.filterContent('paneleiro de merda');
      expect(result.isFlagged, isTrue);
      expect(
        result.flaggedTerms.any((t) => t.category == 'profanidade'),
        isTrue,
      );
      expect(
        result.flaggedTerms.any((t) => t.category == 'discurso de ódio'),
        isTrue,
      );
    });
  });
}
