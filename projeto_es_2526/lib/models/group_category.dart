/// Canonical category keys — stable Firestore identifiers.
/// Never rename a key without a data migration.
const List<String> groupCategories = [
  'Mental Health',
  'Autoimmune Diseases',
  'Neurodivergence',
  'Physical Wellness',
  'General',
];

/// Portuguese display labels for each category key.
const Map<String, String> groupCategoryLabels = {
  'Mental Health': 'Saúde Mental',
  'Autoimmune Diseases': 'Doenças Autoimunes',
  'Neurodivergence': 'Neurodivergência',
  'Physical Wellness': 'Bem-estar Físico',
  'General': 'Geral',
};
