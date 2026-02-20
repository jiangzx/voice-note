import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../transaction/data/transaction_dao.dart';
import '../data/csv_export_strategy.dart';
import '../data/xlsx_export_strategy.dart';
import 'export_config.dart';
import 'export_row.dart';
import 'export_strategy.dart';

/// Progress callback: (processed, total).
typedef ExportProgressCallback = void Function(int processed, int total);

/// Orchestrates batch query → row conversion → file generation → share.
class ExportService {
  final TransactionDao _dao;
  final Future<String> Function(String categoryId) _resolveCategoryName;
  final Future<String> Function(String accountId) _resolveAccountName;

  static const int _batchSize = 500;

  ExportService({
    required TransactionDao dao,
    required Future<String> Function(String categoryId) resolveCategoryName,
    required Future<String> Function(String accountId) resolveAccountName,
  })  : _dao = dao,
        _resolveCategoryName = resolveCategoryName,
        _resolveAccountName = resolveAccountName;

  /// Run export, returning the generated file. Returns null if cancelled or no data.
  Future<File?> export({
    required ExportConfig config,
    ExportProgressCallback? onProgress,
    bool Function()? isCancelled,
  }) async {
    final total = await _getCount(config);
    if (total == 0) return null;

    onProgress?.call(0, total);

    final rows = <ExportRow>[];
    var offset = 0;

    while (offset < total) {
      if (isCancelled?.call() == true) return null;

      final batch = await _dao.getFiltered(
        dateFrom: config.dateFrom,
        dateTo: config.dateTo,
        type: config.transactionType,
        categoryIds:
            config.categoryIds.isNotEmpty ? config.categoryIds : null,
        accountId: config.accountIds.length == 1 ? config.accountIds.first : null,
        limit: _batchSize,
        offset: offset,
      );

      for (final tx in batch) {
        final catName = tx.categoryId != null
            ? await _resolveCategoryName(tx.categoryId!)
            : '';
        final accName = await _resolveAccountName(tx.accountId);
        final typeLabel = switch (tx.type) {
          'expense' => '支出',
          'income' => '收入',
          _ => '转账',
        };

        rows.add(ExportRow(
          date: DateFormat('yyyy-MM-dd').format(tx.date),
          time: DateFormat('HH:mm').format(tx.date),
          type: typeLabel,
          category: catName,
          amount: tx.amount,
          account: accName,
          note: tx.description ?? '',
        ));
      }

      offset += batch.length;
      onProgress?.call(offset.clamp(0, total), total);

      if (batch.length < _batchSize) break;
    }

    if (isCancelled?.call() == true) return null;

    final strategy = _strategyFor(config.format);
    final fileName = generateFileName(config.format);
    final filePath = await tempFilePath(fileName);
    final file = await strategy.generate(rows, filePath);
    return file;
  }

  /// Share a generated file via system Share Sheet.
  Future<void> share(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  /// Generate a timestamped file name.
  static String generateFileName(ExportFormat format) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '快记账_$stamp.${format.extension}';
  }

  /// Get output file path in temp directory.
  static Future<String> tempFilePath(String fileName) async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/$fileName';
  }

  Future<int> _getCount(ExportConfig config) async {
    final all = await _dao.getFiltered(
      dateFrom: config.dateFrom,
      dateTo: config.dateTo,
      type: config.transactionType,
      categoryIds:
          config.categoryIds.isNotEmpty ? config.categoryIds : null,
      accountId: config.accountIds.length == 1 ? config.accountIds.first : null,
    );
    return all.length;
  }

  ExportStrategy _strategyFor(ExportFormat format) => switch (format) {
        ExportFormat.csv => CsvExportStrategy(),
        ExportFormat.xlsx => XlsxExportStrategy(),
      };
}
