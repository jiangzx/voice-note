import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/export/domain/export_config.dart';
import 'package:suikouji/features/export/domain/export_service.dart';
import 'package:suikouji/features/transaction/data/transaction_dao.dart';

void main() {
  late AppDatabase db;
  late TransactionDao txDao;
  late ExportService service;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('export_svc_');

    // Mock path_provider
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getTemporaryDirectory') return tempDir.path;
        return null;
      },
    );

    db = AppDatabase(NativeDatabase.memory());
    txDao = TransactionDao(db);

    service = ExportService(
      dao: txDao,
      resolveCategoryName: (id) async => 'cat-$id',
      resolveAccountName: (id) async => 'acc-$id',
    );

    // Seed 10 transactions
    for (var i = 0; i < 10; i++) {
      await txDao.insertTransaction(TransactionsCompanion.insert(
        id: 'tx-$i',
        type: i % 2 == 0 ? 'expense' : 'income',
        amount: (i + 1) * 10.0,
        date: DateTime(2026, 2, 17, 10 + i),
        accountId: 'acc-1',
        categoryId: Value(i % 2 == 0 ? 'cat-food' : 'cat-salary'),
      ));
    }
  });

  tearDown(() async {
    await db.close();
    tempDir.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });

  test('exports all records when no filter', () async {
    final progressCalls = <(int, int)>[];

    final file = await service.export(
      config: const ExportConfig(format: ExportFormat.csv),
      onProgress: (p, t) => progressCalls.add((p, t)),
    );

    expect(file, isNotNull);
    expect(file!.existsSync(), isTrue);
    expect(progressCalls.isNotEmpty, isTrue);
    expect(progressCalls.last.$1, 10);
    expect(progressCalls.last.$2, 10);
  });

  test('returns null for empty result', () async {
    final file = await service.export(
      config: ExportConfig(
        format: ExportFormat.csv,
        dateFrom: DateTime(2000, 1, 1),
        dateTo: DateTime(2000, 1, 2),
      ),
    );

    expect(file, isNull);
  });

  test('respects cancellation', () async {
    var callCount = 0;

    final file = await service.export(
      config: const ExportConfig(format: ExportFormat.csv),
      isCancelled: () {
        callCount++;
        return callCount > 1;
      },
    );

    expect(file, isNull);
  });

  test('filters by type', () async {
    final file = await service.export(
      config: const ExportConfig(
        format: ExportFormat.csv,
        transactionType: 'expense',
      ),
    );

    expect(file, isNotNull);

    final content = await file!.readAsString();
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
    // Header + 5 expense rows
    expect(lines.length, 6);
  });

  test('generateFileName csv format', () {
    final name = ExportService.generateFileName(ExportFormat.csv);
    expect(name, startsWith('随口记_'));
    expect(name, endsWith('.csv'));
  });

  test('generateFileName xlsx format', () {
    final name = ExportService.generateFileName(ExportFormat.xlsx);
    expect(name, endsWith('.xlsx'));
  });
}
