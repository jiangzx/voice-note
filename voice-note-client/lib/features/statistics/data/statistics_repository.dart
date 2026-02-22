import '../domain/models/category_summary.dart';
import '../domain/models/daily_breakdown_row.dart';
import '../domain/models/period_summary.dart';
import '../domain/models/top_transaction_rank_item.dart';
import '../domain/models/trend_point.dart';
import 'statistics_dao.dart';

/// Repository wrapping [StatisticsDao] and mapping to domain models.
class StatisticsRepository {
  const StatisticsRepository(this._dao);

  final StatisticsDao _dao;

  Future<PeriodSummary> getPeriodSummary({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
  }) async {
    final result = await _dao.getPeriodSummary(
      dateFrom: dateFrom,
      dateTo: dateTo,
      accountId: accountId,
    );
    return PeriodSummary(
      totalIncome: result.totalIncome,
      totalExpense: result.totalExpense,
    );
  }

  /// Returns category summaries with computed percentages.
  Future<List<CategorySummary>> getCategorySummary({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String type,
    String? accountId,
    int maxCategories = 10,
  }) async {
    final rows = await _dao.getCategorySummary(
      dateFrom: dateFrom,
      dateTo: dateTo,
      type: type,
      accountId: accountId,
    );
    if (rows.isEmpty) return [];

    final total = rows.fold<double>(0, (sum, r) => sum + r.totalAmount);
    if (total == 0) return [];

    // Top N + "Other" bucket
    final topRows = rows.take(maxCategories).toList();
    final result = topRows
        .map(
          (r) => CategorySummary(
            categoryId: r.categoryId,
            categoryName: r.categoryName,
            icon: r.icon,
            color: r.color,
            totalAmount: r.totalAmount,
            percentage: (r.totalAmount / total) * 100,
            transactionCount: r.transactionCount,
          ),
        )
        .toList();

    if (rows.length > maxCategories) {
      final otherRows = rows.skip(maxCategories).toList();
      final otherTotal =
          otherRows.fold<double>(0, (s, r) => s + r.totalAmount);
      final otherCount =
          otherRows.fold<int>(0, (s, r) => s + r.transactionCount);
      result.add(CategorySummary(
        categoryId: '_other',
        categoryName: '其他',
        icon: 'material:more_horiz',
        color: 'FF9E9E9E',
        totalAmount: otherTotal,
        percentage: (otherTotal / total) * 100,
        transactionCount: otherCount,
      ));
    }
    return result;
  }

  Future<List<TrendPoint>> getDailyTrend({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
  }) async {
    final rows = await _dao.getDailyTrend(
      dateFrom: dateFrom,
      dateTo: dateTo,
      accountId: accountId,
    );
    return rows
        .map(
          (r) => TrendPoint(date: r.dateLabel, income: r.income, expense: r.expense),
        )
        .toList();
  }

  Future<List<TrendPoint>> getMonthlyTrend({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
  }) async {
    final rows = await _dao.getMonthlyTrend(
      dateFrom: dateFrom,
      dateTo: dateTo,
      accountId: accountId,
    );
    return rows
        .map(
          (r) => TrendPoint(date: r.dateLabel, income: r.income, expense: r.expense),
        )
        .toList();
  }

  /// Top N transactions by amount in period (expense or income). Max 10.
  Future<List<TopTransactionRankItem>> getTopTransactionsByAmount({
    required DateTime dateFrom,
    required DateTime dateTo,
    required String type,
    String? accountId,
    int limit = 10,
  }) async {
    final rows = await _dao.getTopTransactionsByAmount(
      dateFrom: dateFrom,
      dateTo: dateTo,
      type: type,
      accountId: accountId,
      limit: limit,
    );
    return rows
        .map(
          (r) => TopTransactionRankItem(
            id: r.id,
            amount: r.amount,
            description: r.description,
            categoryName: r.categoryName,
            icon: r.icon,
            color: r.color,
          ),
        )
        .toList();
  }

  /// One row per day in range (income, expense, balance). Missing days filled with 0.
  Future<List<DailyBreakdownRow>> getDailyBreakdown({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? accountId,
  }) async {
    final trendRows = await _dao.getDailyTrend(
      dateFrom: dateFrom,
      dateTo: dateTo,
      accountId: accountId,
    );
    final map = {for (final r in trendRows) r.dateLabel: (r.income, r.expense)};
    final result = <DailyBreakdownRow>[];
    var d = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
    final end = DateTime(dateTo.year, dateTo.month, dateTo.day);
    while (!d.isAfter(end)) {
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final pair = map[key] ?? (0.0, 0.0);
      result.add(DailyBreakdownRow(
        dateLabel: key,
        income: pair.$1,
        expense: pair.$2,
      ));
      d = d.add(const Duration(days: 1));
    }
    return result;
  }
}
