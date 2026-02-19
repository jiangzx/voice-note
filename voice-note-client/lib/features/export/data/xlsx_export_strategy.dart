import 'dart:io';

import 'package:excel/excel.dart';

import '../domain/export_row.dart';
import '../domain/export_strategy.dart';

/// Excel XLSX export with detail and summary sheets.
class XlsxExportStrategy implements ExportStrategy {
  @override
  String get fileExtension => 'xlsx';

  @override
  String get mimeType =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  @override
  Future<File> generate(List<ExportRow> rows, String filePath) async {
    final excel = Excel.createExcel();

    _buildDetailSheet(excel, rows);
    _buildSummarySheet(excel, rows);

    // Remove default "Sheet1" created by the library
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.save();
    if (bytes == null) throw StateError('Failed to encode Excel');

    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return file;
  }

  void _buildDetailSheet(Excel excel, List<ExportRow> rows) {
    final sheet = excel['交易明细'];

    // Headers
    for (var i = 0; i < ExportRow.headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value =
          TextCellValue(ExportRow.headers[i]);
    }

    // Data rows
    for (var r = 0; r < rows.length; r++) {
      final values = rows[r].toList();
      for (var c = 0; c < values.length; c++) {
        final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));

        // Amount column (index 4): use numeric value
        if (c == 4) {
          cell.value = DoubleCellValue(rows[r].amount);
        } else {
          cell.value = TextCellValue(values[c]);
        }
      }
    }
  }

  void _buildSummarySheet(Excel excel, List<ExportRow> rows) {
    final sheet = excel['分类汇总'];

    // Headers
    const summaryHeaders = ['分类', '类型', '金额合计'];
    for (var i = 0; i < summaryHeaders.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value =
          TextCellValue(summaryHeaders[i]);
    }

    // Aggregate by category + type
    final Map<String, Map<String, double>> grouped = {};
    for (final row in rows) {
      final key = '${row.category}|${row.type}';
      grouped.putIfAbsent(key, () => {'amount': 0});
      grouped[key]!['amount'] = grouped[key]!['amount']! + row.amount;
    }

    var rowIdx = 1;
    final sortedKeys = grouped.keys.toList()..sort();
    for (final key in sortedKeys) {
      final parts = key.split('|');
      final category = parts[0];
      final type = parts[1];
      final amount = grouped[key]!['amount']!;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIdx))
          .value = TextCellValue(category);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIdx))
          .value = TextCellValue(type);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIdx))
          .value = DoubleCellValue(amount);

      rowIdx++;
    }
  }
}
