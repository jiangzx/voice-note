import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';

import '../domain/export_row.dart';
import '../domain/export_strategy.dart';

/// CSV export with UTF-8 BOM for Chinese compatibility.
class CsvExportStrategy implements ExportStrategy {
  @override
  String get fileExtension => 'csv';

  @override
  String get mimeType => 'text/csv';

  @override
  Future<File> generate(List<ExportRow> rows, String filePath) async {
    final data = [
      ExportRow.headers,
      ...rows.map((r) => r.toList()),
    ];

    final csvString = const ListToCsvConverter().convert(data);
    final file = File(filePath);

    // UTF-8 BOM + CSV content
    final bom = [0xEF, 0xBB, 0xBF];
    await file.writeAsBytes([...bom, ...utf8.encode(csvString)]);

    return file;
  }
}
