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

  group('isAtLeastMinimumAge', () {
    DateTime yearsAgo(int years, {int days = 0}) {
      final today = DateTime.now();
      return DateTime(
        today.year - years,
        today.month,
        today.day,
      ).add(Duration(days: days));
    }

    test('returns true for someone comfortably older than the minimum', () {
      expect(isAtLeastMinimumAge(yearsAgo(30)), isTrue);
    });

    test('returns true for someone turning the minimum age today', () {
      expect(isAtLeastMinimumAge(yearsAgo(minimumAgeYears)), isTrue);
    });

    test('returns false for someone one day short of the minimum', () {
      expect(isAtLeastMinimumAge(yearsAgo(minimumAgeYears, days: 1)), isFalse);
    });

    test('returns false for someone well under the minimum', () {
      expect(isAtLeastMinimumAge(yearsAgo(5)), isFalse);
    });

    test('ignores the time component of the date of birth', () {
      final today = DateTime.now();
      final exactlyMinimumWithTime = DateTime(
        today.year - minimumAgeYears,
        today.month,
        today.day,
        23,
        59,
        59,
      );
      expect(isAtLeastMinimumAge(exactlyMinimumWithTime), isTrue);
    });
  });
}
