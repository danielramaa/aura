enum UserRole {
  user,
  medic,
  admin;

  static UserRole fromString(String? value) => UserRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => UserRole.user,
  );

  String get firestoreValue => name;
}
