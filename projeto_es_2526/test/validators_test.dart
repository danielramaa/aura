import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_es_2526/utils/validators.dart';

void main() {
  group('validateEmail', () {
    test('returns error when input is null', () {
      expect(validateEmail(null), isNotNull);
    });

    test('returns error when input is empty', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('   '), isNotNull);
    });

    test('returns error for missing "@"', () {
      expect(validateEmail('userexample.com'), isNotNull);
    });

    test('returns error for missing domain', () {
      expect(validateEmail('user@'), isNotNull);
    });

    test('returns error for missing TLD', () {
      expect(validateEmail('user@domain'), isNotNull);
    });

    test('returns error when email contains whitespace', () {
      expect(validateEmail('us er@domain.com'), isNotNull);
    });

    test('returns null for a valid email', () {
      expect(validateEmail('user@example.com'), isNull);
      expect(validateEmail('first.last+tag@sub.domain.co'), isNull);
    });

    test('trims surrounding whitespace before validating', () {
      expect(validateEmail('  user@example.com  '), isNull);
    });
  });
}
