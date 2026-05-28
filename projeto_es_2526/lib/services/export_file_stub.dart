/// Web fallback: there is no local filesystem (`dart:io` is unavailable), so we
/// don't write a file and return an empty path. The app is mobile-only at
/// runtime, so this is never actually reached — it exists purely so the project
/// still compiles for the web target.
Future<String> writeExportDataFile(
  String uid,
  Map<String, dynamic> data,
) async {
  return '';
}
