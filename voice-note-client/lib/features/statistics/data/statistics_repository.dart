import '../domain/models/category_summary.dart';
import '../domain/models/period_summary.dart';
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
          ),
        )
        .toList();

    if (rows.length > maxCategories) {
      final otherTotal =
          rows.skip(maxCategories).fold<double>(0, (s, r) => s + r.totalAmount);
      result.add(CategorySummary(
        categoryId: '_other',
        categoryName: '其他',
        icon: 'material:more_horiz',
        color: 'FF9E9E9E',
        totalAmount: otherTotal,
        percentage: (otherTotal / total) * 100,
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
}
