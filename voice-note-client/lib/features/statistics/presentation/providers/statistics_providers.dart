import 'package:riverpod/legacy.dart' show StateProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/database_provider.dart';
import '../../data/statistics_repository.dart';
import '../../domain/models/category_summary.dart';
import '../../domain/models/period_summary.dart';
import '../../domain/models/trend_point.dart';

part 'statistics_providers.g.dart';

/// Period type for statistics view.
enum PeriodType { day, week, month, year }

final selectedPeriodTypeProvider =
    StateProvider.autoDispose<PeriodType>((ref) => PeriodType.month);
final selectedDateProvider =
    StateProvider.autoDispose<DateTime>((ref) => DateTime.now());
final selectedAccountIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final categorySummaryTypeProvider =
    StateProvider.autoDispose<String>((ref) => 'expense');

@Riverpod(keepAlive: true)
StatisticsRepository statisticsRepository(Ref ref) {
  return StatisticsRepository(ref.watch(statisticsDaoProvider));
}

@riverpod
Future<PeriodSummary> periodSummary(Ref ref) async {
  final periodType = ref.watch(selectedPeriodTypeProvider);
  final date = ref.watch(selectedDateProvider);
  final accountId = ref.watch(selectedAccountIdProvider);
  final range = dateRangeForPeriod(date, periodType);
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
    case PeriodType.day:
      return date.subtract(const Duration(days: 1));
    case PeriodType.week:
      return date.subtract(const Duration(days: 7));
    case PeriodType.month:
      return DateTime(date.year, date.month - 1, date.day);
    case PeriodType.year:
      return DateTime(date.year - 1, date.month, date.day);
  }
}

@riverpod
Future<List<CategorySummary>> categorySummary(Ref ref) async {
  final periodType = ref.watch(selectedPeriodTypeProvider);
  final date = ref.watch(selectedDateProvider);
  final accountId = ref.watch(selectedAccountIdProvider);
  final range = dateRangeForPeriod(date, periodType);
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
  final date = ref.watch(selectedDateProvider);
  final accountId = ref.watch(selectedAccountIdProvider);
  final range = dateRangeForPeriod(date, periodType);
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

/// Returns (start, end) for the given period type centered on [date].
({DateTime start, DateTime end}) dateRangeForPeriod(
  DateTime date,
  PeriodType type,
) {
  final base = DateTime(date.year, date.month, date.day);
  switch (type) {
    case PeriodType.day:
      return (
        start: base,
        end: DateTime(base.year, base.month, base.day, 23, 59, 59),
      );
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
  }
}
