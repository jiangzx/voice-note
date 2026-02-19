import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/export/data/csv_export_strategy.dart';
import 'package:suikouji/features/export/domain/export_row.dart';

void main() {
  late CsvExportStrategy strategy;
  late Directory tempDir;

  setUp(() {
    strategy = CsvExportStrategy();
    tempDir = Directory.systemTemp.createTempSync('csv_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  String tempPath(String name) => '${tempDir.path}/$name';

  test('fileExtension is csv', () {
    expect(strategy.fileExtension, 'csv');
  });

  test('mimeType is text/csv', () {
    expect(strategy.mimeType, 'text/csv');
  });

  test('generates CSV with BOM and headers', () async {
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
    ];

    final file = await strategy.generate(rows, tempPath('test.csv'));

    expect(file.existsSync(), isTrue);

    final bytes = await file.readAsBytes();
    // Check BOM
    expect(bytes[0], 0xEF);
    expect(bytes[1], 0xBB);
    expect(bytes[2], 0xBF);

    final content = utf8.decode(bytes.sublist(3));
    final lines = content.split('\r\n');

    expect(lines[0], '日期,时间,类型,分类,金额,账户,备注');
    expect(lines[1], '2026-02-17,12:00,支出,餐饮,35.50,钱包,午餐');
  });

  test('handles empty note', () async {
    final rows = [
      const ExportRow(
        date: '2026-01-01',
        time: '09:00',
        type: '收入',
        category: '工资',
        amount: 10000.00,
        account: '银行卡',
      ),
    ];

    final file = await strategy.generate(rows, tempPath('empty_note.csv'));

    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes.sublist(3));
    final lines = content.split('\r\n');
    expect(lines[1], '2026-01-01,09:00,收入,工资,10000.00,银行卡,');
  });

  test('handles note with comma', () async {
    final rows = [
      const ExportRow(
        date: '2026-01-01',
        time: '09:00',
        type: '支出',
        category: '餐饮',
        amount: 50.00,
        account: '钱包',
        note: '早餐,午餐',
      ),
    ];

    final file = await strategy.generate(rows, tempPath('comma.csv'));

    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes.sublist(3));
    final lines = content.split('\r\n');
    expect(lines[1], contains('"早餐,午餐"'));
  });

  test('handles empty rows - header only', () async {
    final file = await strategy.generate([], tempPath('empty.csv'));

    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes.sublist(3));
    expect(content.trim(), '日期,时间,类型,分类,金额,账户,备注');
  });
}
