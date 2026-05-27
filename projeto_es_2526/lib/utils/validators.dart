final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Enter your email';
  if (!_emailRegex.hasMatch(email)) return 'Enter a valid email address';
  return null;
}

/// Minimum age required to register, per the Terms and Conditions.
const minimumAgeYears = 13;

/// Returns true when [dateOfBirth] corresponds to someone who is at least
/// [minimumAgeYears] old today. Turning the minimum age today counts as old
/// enough.
bool isAtLeastMinimumAge(DateTime dateOfBirth) {
  final today = DateTime.now();
  final cutoff = DateTime(
    today.year - minimumAgeYears,
    today.month,
    today.day,
  );
  final normalized = DateTime(
    dateOfBirth.year,
    dateOfBirth.month,
    dateOfBirth.day,
  );
  return !normalized.isAfter(cutoff);
}
