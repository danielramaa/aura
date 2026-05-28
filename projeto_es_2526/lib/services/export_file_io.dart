import 'dart:convert';
import 'dart:io';

/// Writes the export [data] as pretty-printed JSON to a temp file and returns
/// its path. Used on platforms with a local filesystem (mobile/desktop).
Future<String> writeExportDataFile(
  String uid,
  Map<String, dynamic> data,
) async {
  final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
  final file = File('${Directory.systemTemp.path}/export_data_$uid.json');
  await file.writeAsString(jsonStr, flush: true);
  return file.path;
}
