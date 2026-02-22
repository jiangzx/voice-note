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

  /// Get income/expense totals for a date range. Includes transfer: inbound as income, outbound as expense.
  Future<({double totalIncome, double totalExpense})> getPeriodSummary({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
  }) async {
    final sumCol = transactions.amount.sum();
    var baseFilter = transactions.date.isBiggerOrEqualValue(dateFrom) &
        transactions.date.isSmallerOrEqualValue(dateTo) &
        transactions.isDraft.equals(false);
    if (accountId != null) {
      baseFilter = baseFilter & transactions.accountId.equals(accountId);
    }

    final incomeFilter = baseFilter &
        (transactions.type.equals('income') |
            (transactions.type.equals('transfer') &
                transactions.transferDirection.equals('in')));
    final expenseFilter = baseFilter &
        (transactions.type.equals('expense') |
            (transactions.type.equals('transfer') &
                transactions.transferDirection.equals('out')));

    final incomeQuery = selectOnly(transactions)
      ..addColumns([sumCol])
      ..where(incomeFilter);
    final expenseQuery = selectOnly(transactions)
      ..addColumns([sumCol])
      ..where(expenseFilter);

    final incomeRow = await incomeQuery.getSingle();
    final expenseRow = await expenseQuery.getSingle();
    return (
      totalIncome: incomeRow.read(sumCol) ?? 0.0,
      totalExpense: expenseRow.read(sumCol) ?? 0.0,
    );
  }

  /// Get per-category totals. For type expense includes transfer out; for type income includes transfer in.
  Future<List<CategorySummaryRow>> getCategorySummary({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String type,
    String? accountId,
  }) async {
    final sumExpr = transactions.amount.sum();
    final typeFilter = type == 'expense'
        ? (transactions.type.equals('expense') |
            (transactions.type.equals('transfer') &
                transactions.transferDirection.equals('out')))
        : (transactions.type.equals('income') |
            (transactions.type.equals('transfer') &
                transactions.transferDirection.equals('in')));
    var filter = transactions.date.isBiggerOrEqualValue(dateFrom) &
        transactions.date.isSmallerOrEqualValue(dateTo) &
        transactions.isDraft.equals(false) &
        typeFilter &
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

  /// Get daily income/expense trend. Income = type income or transfer in; expense = type expense or transfer out.
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
        (transactions.type.isIn(['income', 'expense']) |
            transactions.type.equals('transfer'));
    if (accountId != null) {
      filter = filter & transactions.accountId.equals(accountId);
    }

    final query = selectOnly(transactions)
      ..addColumns([
        dateExpr,
        transactions.type,
        transactions.transferDirection,
        sumExpr,
      ])
      ..where(filter)
      ..groupBy([dateExpr, transactions.type, transactions.transferDirection])
      ..orderBy([OrderingTerm.asc(dateExpr)]);

    final rows = await query.get();

    final map = <String, ({double income, double expense})>{};
    for (final row in rows) {
      final date = row.read(dateExpr) ?? '';
      final type = row.read(transactions.type) ?? '';
      final dir = row.read(transactions.transferDirection);
      final amount = row.read(sumExpr) ?? 0.0;
      final existing = map[date] ?? (income: 0.0, expense: 0.0);
      final isIncome = type == 'income' || (type == 'transfer' && dir == 'in');
      if (isIncome) {
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

  /// Get monthly income/expense trend (year view). Same income/expense口径 as getDailyTrend.
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
        (transactions.type.isIn(['income', 'expense']) |
            transactions.type.equals('transfer'));
    if (accountId != null) {
      filter = filter & transactions.accountId.equals(accountId);
    }

    final query = selectOnly(transactions)
      ..addColumns([
        monthExpr,
        transactions.type,
        transactions.transferDirection,
        sumExpr,
      ])
      ..where(filter)
      ..groupBy([monthExpr, transactions.type, transactions.transferDirection])
      ..orderBy([OrderingTerm.asc(monthExpr)]);

    final rows = await query.get();

    final map = <String, ({double income, double expense})>{};
    for (final row in rows) {
      final month = row.read(monthExpr) ?? '';
      final type = row.read(transactions.type) ?? '';
      final dir = row.read(transactions.transferDirection);
      final amount = row.read(sumExpr) ?? 0.0;
      final existing = map[month] ?? (income: 0.0, expense: 0.0);
      final isIncome = type == 'income' || (type == 'transfer' && dir == 'in');
      if (isIncome) {
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
