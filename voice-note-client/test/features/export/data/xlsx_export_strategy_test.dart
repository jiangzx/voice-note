import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/export/data/xlsx_export_strategy.dart';
import 'package:suikouji/features/export/domain/export_row.dart';

void main() {
  late XlsxExportStrategy strategy;
  late Directory tempDir;

  setUp(() {
    strategy = XlsxExportStrategy();
    tempDir = Directory.systemTemp.createTempSync('xlsx_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String tempPath(String name) => '${tempDir.path}/$name';

  test('fileExtension is xlsx', () {
    expect(strategy.fileExtension, 'xlsx');
  });

  test('generates XLSX with detail and summary sheets', () async {
    final rows = [
      const ExportRow(
        date: '2026-02-17',
        time: '12:00',
        type: '支出',
        category: '餐饮',
        amount: 35.50,
        account: '钱包',
        note: '午餐',
      ),
      const ExportRow(
        date: '2026-02-17',
        time: '18:00',
        type: '支出',
        category: '餐饮',
        amount: 50.00,
        account: '钱包',
        note: '晚餐',
      ),
      const ExportRow(
        date: '2026-02-17',
        time: '09:00',
        type: '收入',
        category: '工资',
        amount: 10000.00,
        account: '银行卡',
      ),
    ];

    final file = await strategy.generate(rows, tempPath('test.xlsx'));
    expect(file.existsSync(), isTrue);

    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    expect(excel.sheets.containsKey('交易明细'), isTrue);
    expect(excel.sheets.containsKey('分类汇总'), isTrue);

    // Detail sheet: header + 3 rows
    final detail = excel.sheets['交易明细']!;
    expect(detail.maxRows, 4);

    // First data row check
    expect(
      detail.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value,
      isA<TextCellValue>(),
    );

    // Summary sheet: header + 2 categories (餐饮|支出, 工资|收入)
    final summary = excel.sheets['分类汇总']!;
    expect(summary.maxRows, 3);
  });

  test('summary sheet aggregates correctly', () async {
    final rows = [
      const ExportRow(
        date: '2026-01-01',
        time: '10:00',
        type: '支出',
        category: '餐饮',
        amount: 100.00,
        account: '钱包',
      ),
      const ExportRow(
        date: '2026-01-02',
        time: '11:00',
        type: '支出',
        category: '餐饮',
        amount: 200.00,
        account: '钱包',
      ),
    ];

    final file = await strategy.generate(rows, tempPath('agg.xlsx'));
    final excel = Excel.decodeBytes(file.readAsBytesSync());
    final summary = excel.sheets['分类汇总']!;

    expect(summary.maxRows, 2); // header + 1 aggregated row
    final amountCell =
        summary.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 1));
    final cellValue = amountCell.value;
    final amount = cellValue is DoubleCellValue
        ? cellValue.value
        : (cellValue as IntCellValue).value.toDouble();
    expect(amount, 300.0);
  });

  test('handles empty rows', () async {
    final file = await strategy.generate([], tempPath('empty.xlsx'));
    final excel = Excel.decodeBytes(file.readAsBytesSync());
    final detail = excel.sheets['交易明细']!;
    expect(detail.maxRows, 1); // header only
  });
}
