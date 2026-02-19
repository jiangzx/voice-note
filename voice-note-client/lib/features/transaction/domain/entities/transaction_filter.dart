/// Value object for transaction query filters.
/// All fields are optional; non-null fields are combined with AND logic.
class TransactionFilter {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final List<String>? categoryIds;
  final String? accountId;
  final double? minAmount;
  final double? maxAmount;
  final String? keyword;
  final String? type; // expense | income | transfer

  const TransactionFilter({
    this.dateFrom,
    this.dateTo,
    this.categoryIds,
    this.accountId,
    this.minAmount,
    this.maxAmount,
    this.keyword,
    this.type,
  });

  TransactionFilter copyWith({
    DateTime? Function()? dateFrom,
    DateTime? Function()? dateTo,
    List<String>? Function()? categoryIds,
    String? Function()? accountId,
    double? Function()? minAmount,
    double? Function()? maxAmount,
    String? Function()? keyword,
    String? Function()? type,
  }) {
    return TransactionFilter(
      dateFrom: dateFrom != null ? dateFrom() : this.dateFrom,
      dateTo: dateTo != null ? dateTo() : this.dateTo,
      categoryIds: categoryIds != null ? categoryIds() : this.categoryIds,
      accountId: accountId != null ? accountId() : this.accountId,
      minAmount: minAmount != null ? minAmount() : this.minAmount,
      maxAmount: maxAmount != null ? maxAmount() : this.maxAmount,
      keyword: keyword != null ? keyword() : this.keyword,
      type: type != null ? type() : this.type,
    );
  }
}

/// Summary of income and expense for a date range.
class TransactionSummary {
  final double totalIncome;
  final double totalExpense;

  const TransactionSummary({
    required this.totalIncome,
    required this.totalExpense,
  });

  double get netAmount => totalIncome - totalExpense;
}

/// A group of transactions on the same day with daily subtotals.
class DailyTransactionGroup {
  final DateTime date;
  final double dailyIncome;
  final double dailyExpense;
  final List<dynamic> transactions;

  const DailyTransactionGroup({
    required this.date,
    required this.dailyIncome,
    required this.dailyExpense,
    required this.transactions,
  });
}
