/// Supported export formats.
enum ExportFormat {
  csv,
  xlsx;

  String get extension => name;

  String get label => switch (this) {
        csv => 'CSV',
        xlsx => 'Excel (XLSX)',
      };
}

/// Configuration for a data export operation.
class ExportConfig {
  final ExportFormat format;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? transactionType; // 'expense', 'income', or null for all
  final List<String> categoryIds;
  final List<String> accountIds;

  const ExportConfig({
    required this.format,
    this.dateFrom,
    this.dateTo,
    this.transactionType,
    this.categoryIds = const [],
    this.accountIds = const [],
  });

  bool get hasFilters =>
      dateFrom != null ||
      dateTo != null ||
      transactionType != null ||
      categoryIds.isNotEmpty ||
      accountIds.isNotEmpty;
}
