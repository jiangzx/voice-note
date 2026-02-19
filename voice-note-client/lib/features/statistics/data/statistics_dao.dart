import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

part 'statistics_dao.g.dart';

/// Raw row from category summary aggregation query.
class CategorySummaryRow {
  const CategorySummaryRow({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.totalAmount,
  });

  final String categoryId;
  final String categoryName;
  final String icon;
  final String color;
  final double totalAmount;
}

/// Raw row from daily/monthly trend query.
class TrendRow {
  const TrendRow({
    required this.dateLabel,
    required this.income,
    required this.expense,
  });

  final String dateLabel;
  final double income;
  final double expense;
}

@DriftAccessor(tables: [Transactions, Categories])
class StatisticsDao extends DatabaseAccessor<AppDatabase>
    with _$StatisticsDaoMixin {
  StatisticsDao(super.db);

  /// Get income/expense totals for a date range using SQL aggregation.
  Future<({double totalIncome, double totalExpense})> getPeriodSummary({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
  }) async {
    final sumCol = transactions.amount.sum();
    var filter = transactions.date.isBiggerOrEqualValue(dateFrom) &
        transactions.date.isSmallerOrEqualValue(dateTo) &
        transactions.isDraft.equals(false) &
        transactions.type.isIn(['income', 'expense']);
    if (accountId != null) {
      filter = filter & transactions.accountId.equals(accountId);
    }

    final query = selectOnly(transactions)
      ..addColumns([transactions.type, sumCol])
      ..where(filter)
      ..groupBy([transactions.type]);

    final rows = await query.get();
    var totalIncome = 0.0;
    var totalExpense = 0.0;
    for (final row in rows) {
      final type = row.read(transactions.type);
      final sum = row.read(sumCol) ?? 0.0;
      if (type == 'income') {
        totalIncome = sum;
      } else if (type == 'expense') {
        totalExpense = sum;
      }
    }
    return (totalIncome: totalIncome, totalExpense: totalExpense);
  }

  /// Get per-category totals for a date range.
  Future<List<CategorySummaryRow>> getCategorySummary({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String type,
    String? accountId,
  }) async {
    final sumExpr = transactions.amount.sum();
    var filter = transactions.date.isBiggerOrEqualValue(dateFrom) &
        transactions.date.isSmallerOrEqualValue(dateTo) &
        transactions.isDraft.equals(false) &
        transactions.type.equals(type) &
        transactions.categoryId.isNotNull();
    if (accountId != null) {
      filter = filter & transactions.accountId.equals(accountId);
    }

    final query = selectOnly(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ])
      ..addColumns([
        categories.id,
        categories.name,
        categories.icon,
        categories.color,
        sumExpr,
      ])
      ..where(filter)
      ..groupBy([transactions.categoryId])
      ..orderBy([OrderingTerm.desc(sumExpr)]);

    final rows = await query.get();
    return rows.map(
      (row) => CategorySummaryRow(
        categoryId: row.read(categories.id)!,
        categoryName: row.read(categories.name)!,
        icon: row.read(categories.icon)!,
        color: row.read(categories.color)!,
        totalAmount: row.read(sumExpr) ?? 0.0,
      ),
    ).toList();
  }

  /// Get daily income/expense trend for a date range.
  Future<List<TrendRow>> getDailyTrend({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
  }) async {
    final dateExpr = transactions.date.date;
    final sumExpr = transactions.amount.sum();
    var filter = transactions.date.isBiggerOrEqualValue(dateFrom) &
        transactions.date.isSmallerOrEqualValue(dateTo) &
        transactions.isDraft.equals(false) &
        transactions.type.isIn(['income', 'expense']);
    if (accountId != null) {
      filter = filter & transactions.accountId.equals(accountId);
    }

    final query = selectOnly(transactions)
      ..addColumns([
        dateExpr,
        transactions.type,
        sumExpr,
      ])
      ..where(filter)
      ..groupBy([dateExpr, transactions.type])
      ..orderBy([OrderingTerm.asc(dateExpr)]);

    final rows = await query.get();

    final map = <String, ({double income, double expense})>{};
    for (final row in rows) {
      final date = row.read(dateExpr) ?? '';
      final type = row.read(transactions.type) ?? '';
      final amount = row.read(sumExpr) ?? 0.0;
      final existing = map[date] ?? (income: 0.0, expense: 0.0);
      if (type == 'income') {
        map[date] = (income: existing.income + amount, expense: existing.expense);
      } else {
        map[date] = (income: existing.income, expense: existing.expense + amount);
      }
    }

    return map.entries
        .map(
          (e) => TrendRow(
            dateLabel: e.key,
            income: e.value.income,
            expense: e.value.expense,
          ),
        )
        .toList();
  }

  /// Get monthly income/expense trend for a date range (year view).
  Future<List<TrendRow>> getMonthlyTrend({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
  }) async {
    final monthExpr = transactions.date.strftime('%Y-%m');
    final sumExpr = transactions.amount.sum();
    var filter = transactions.date.isBiggerOrEqualValue(dateFrom) &
        transactions.date.isSmallerOrEqualValue(dateTo) &
        transactions.isDraft.equals(false) &
        transactions.type.isIn(['income', 'expense']);
    if (accountId != null) {
      filter = filter & transactions.accountId.equals(accountId);
    }

    final query = selectOnly(transactions)
      ..addColumns([
        monthExpr,
        transactions.type,
        sumExpr,
      ])
      ..where(filter)
      ..groupBy([monthExpr, transactions.type])
      ..orderBy([OrderingTerm.asc(monthExpr)]);

    final rows = await query.get();

    final map = <String, ({double income, double expense})>{};
    for (final row in rows) {
      final month = row.read(monthExpr) ?? '';
      final type = row.read(transactions.type) ?? '';
      final amount = row.read(sumExpr) ?? 0.0;
      final existing = map[month] ?? (income: 0.0, expense: 0.0);
      if (type == 'income') {
        map[month] =
            (income: existing.income + amount, expense: existing.expense);
      } else {
        map[month] =
            (income: existing.income, expense: existing.expense + amount);
      }
    }

    return map.entries
        .map(
          (e) => TrendRow(
            dateLabel: e.key,
            income: e.value.income,
            expense: e.value.expense,
          ),
        )
        .toList();
  }

  /// Get total expense for a specific category in a date range.
  Future<double> getCategoryExpenseTotal({
    required String categoryId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final sumExpr = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..addColumns([sumExpr])
      ..where(
        transactions.categoryId.equals(categoryId) &
            transactions.type.equals('expense') &
            transactions.isDraft.equals(false) &
            transactions.date.isBiggerOrEqualValue(dateFrom) &
            transactions.date.isSmallerOrEqualValue(dateTo),
      );
    final row = await query.getSingle();
    return row.read(sumExpr) ?? 0.0;
  }
}
