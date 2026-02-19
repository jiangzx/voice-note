import 'dart:io';

import 'export_row.dart';

/// Abstract strategy for generating export files.
abstract class ExportStrategy {
  String get fileExtension;
  String get mimeType;

  /// Generate export file at [filePath] from flat rows.
  Future<File> generate(List<ExportRow> rows, String filePath);
}
