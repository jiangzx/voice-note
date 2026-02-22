import 'package:flutter/material.dart';
import 'package:riverpod/legacy.dart' show StateProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/database_provider.dart';
import '../../data/statistics_repository.dart';
import '../../domain/models/category_summary.dart';
import '../../domain/models/daily_breakdown_row.dart';
import '../../domain/models/period_summary.dart';
import '../../domain/models/top_transaction_rank_item.dart';
import '../../domain/models/trend_point.dart';

part 'statistics_providers.g.dart';

/// Period type for statistics view: 周 | 月 | 年 | 自定义.
enum PeriodType { week, month, year, custom }

final selectedPeriodTypeProvider =
    StateProvider.autoDispose<PeriodType>((ref) => PeriodType.month);
final selectedDateProvider =
    StateProvider.autoDispose<DateTime>((ref) => DateTime.now());
/// When [selectedPeriodTypeProvider] is [PeriodType.custom], this range is used.
final customDateRangeProvider =
    StateProvider.autoDispose<DateTimeRange?>((ref) => null);
final selectedAccountIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final categorySummaryTypeProvider =
    StateProvider.autoDispose<String>((ref) => 'expense');
/// 单笔支出排行榜: 支出 | 收入（与支出分类构成独立）.
final singleRankingTypeProvider =
    StateProvider.autoDispose<String>((ref) => 'expense');
/// 每日趋势 chart: 支出 | 收入 | 结余.
final trendSeriesProvider =
    StateProvider.autoDispose<String>((ref) => 'expense');

@Riverpod(keepAlive: true)
StatisticsRepository statisticsRepository(Ref ref) {
  return StatisticsRepository(ref.watch(statisticsDaoProvider));
}

/// Effective date range for current period selection.
class EffectiveDateRange {
  const EffectiveDateRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

@riverpod
EffectiveDateRange effectiveDateRange(Ref ref) {
  final periodType = ref.watch(selectedPeriodTypeProvider);
  final date = ref.watch(selectedDateProvider);
  final custom = ref.watch(customDateRangeProvider);
  if (periodType == PeriodType.custom && custom != null) {
    return EffectiveDateRange(start: custom.start, end: custom.end);
  }
  final r = dateRangeForPeriod(date, periodType);
  return EffectiveDateRange(start: r.start, end: r.end);
}

@riverpod
Future<PeriodSummary> periodSummary(Ref ref) async {
  final accountId = ref.watch(selectedAccountIdProvider);
  final range = ref.watch(effectiveDateRangeProvider);
  final repo = ref.watch(statisticsRepositoryProvider);
  return repo.getPeriodSummary(
    dateFrom: range.start,
    dateTo: range.end,
    accountId: accountId,
  );
}

@riverpod
Future<PeriodSummary> previousPeriodSummary(Ref ref) async {
  final periodType = ref.watch(selectedPeriodTypeProvider);
  final date = ref.watch(selectedDateProvider);
  final accountId = ref.watch(selectedAccountIdProvider);
  final prevDate = _previousPeriodDate(date, periodType);
  final range = dateRangeForPeriod(prevDate, periodType);
  final repo = ref.watch(statisticsRepositoryProvider);
  return repo.getPeriodSummary(
    dateFrom: range.start,
    dateTo: range.end,
    accountId: accountId,
  );
}

DateTime _previousPeriodDate(DateTime date, PeriodType type) {
  switch (type) {
    case PeriodType.week:
      return date.subtract(const Duration(days: 7));
    case PeriodType.month:
      return DateTime(date.year, date.month - 1, date.day);
    case PeriodType.year:
      return DateTime(date.year - 1, date.month, date.day);
    case PeriodType.custom:
      return date;
  }
}

@riverpod
Future<List<CategorySummary>> categorySummary(Ref ref) async {
  final accountId = ref.watch(selectedAccountIdProvider);
  final range = ref.watch(effectiveDateRangeProvider);
  final repo = ref.watch(statisticsRepositoryProvider);
  final type = ref.watch(categorySummaryTypeProvider);
  return repo.getCategorySummary(
    dateFrom: range.start,
    dateTo: range.end,
    type: type,
    accountId: accountId,
  );
}

@riverpod
Future<List<TrendPoint>> trendData(Ref ref) async {
  final periodType = ref.watch(selectedPeriodTypeProvider);
  final accountId = ref.watch(selectedAccountIdProvider);
  final range = ref.watch(effectiveDateRangeProvider);
  final repo = ref.watch(statisticsRepositoryProvider);
  if (periodType == PeriodType.year) {
    return repo.getMonthlyTrend(
      dateFrom: range.start,
      dateTo: range.end,
      accountId: accountId,
    );
  }
  return repo.getDailyTrend(
    dateFrom: range.start,
    dateTo: range.end,
    accountId: accountId,
  );
}

@riverpod
Future<List<DailyBreakdownRow>> dailyBreakdown(Ref ref) async {
  final accountId = ref.watch(selectedAccountIdProvider);
  final range = ref.watch(effectiveDateRangeProvider);
  final repo = ref.watch(statisticsRepositoryProvider);
  return repo.getDailyBreakdown(
    dateFrom: range.start,
    dateTo: range.end,
    accountId: accountId,
  );
}

@riverpod
Future<List<TopTransactionRankItem>> topTransactionsByAmount(Ref ref) async {
  final accountId = ref.watch(selectedAccountIdProvider);
  final range = ref.watch(effectiveDateRangeProvider);
  final type = ref.watch(singleRankingTypeProvider);
  final repo = ref.watch(statisticsRepositoryProvider);
  return repo.getTopTransactionsByAmount(
    dateFrom: range.start,
    dateTo: range.end,
    type: type,
    accountId: accountId,
    limit: 10,
  );
}

/// Returns (start, end) for the given period type centered on [date]. [PeriodType.custom] is not handled here.
({DateTime start, DateTime end}) dateRangeForPeriod(
  DateTime date,
  PeriodType type,
) {
  final base = DateTime(date.year, date.month, date.day);
  switch (type) {
    case PeriodType.week:
      final monday = base.subtract(Duration(days: base.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      return (
        start: monday,
        end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59),
      );
    case PeriodType.month:
      final lastDay = DateTime(base.year, base.month + 1, 0);
      return (
        start: DateTime(base.year, base.month, 1),
        end: DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59),
      );
    case PeriodType.year:
      return (
        start: DateTime(base.year, 1, 1),
        end: DateTime(base.year, 12, 31, 23, 59, 59),
      );
    case PeriodType.custom:
      return (start: base, end: base);
  }
}
