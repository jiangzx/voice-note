import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_filter.dart';
import 'recent_transactions_paged_provider.dart';
import 'transaction_form_providers.dart';

part 'transaction_query_providers.g.dart';

/// Invalidate all transaction query providers to refresh UI after data changes.
void invalidateTransactionQueries(dynamic ref) {
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(summaryProvider);
  ref.invalidate(dailyGroupedProvider);
  ref.invalidate(transactionListProvider);
  ref.invalidate(calendarMonthGroupsProvider);
  ref.invalidate(selectedDateTransactionsProvider);
  ref.read(recentTransactionsPagedProvider.notifier).refresh();
}

@riverpod
Future<List<TransactionEntity>> transactionList(
  Ref ref,
  TransactionFilter filter,
) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getFiltered(filter);
}

@riverpod
Future<TransactionSummary> summary(
  Ref ref,
  DateTime dateFrom,
  DateTime dateTo,
) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getSummary(dateFrom, dateTo);
}

@riverpod
Future<List<TransactionEntity>> recentTransactions(Ref ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getRecent(5);
}

@riverpod
Future<List<DailyTransactionGroup>> dailyGrouped(
  Ref ref,
  DateTime dateFrom,
  DateTime dateTo,
) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getDailyGrouped(dateFrom, dateTo);
}

/// Calendar grid data for the given month (date/dailyIncome/dailyExpense only).
@riverpod
Future<List<DailyTransactionGroup>> calendarMonthGroups(
  Ref ref,
  DateTime currentMonth,
) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final start = DateTime(currentMonth.year, currentMonth.month, 1);
  final end = DateTime(currentMonth.year, currentMonth.month + 1, 0);
  return repo.getDailyGrouped(start, end);
}

/// Transactions for the selected day only (drives list below calendar).
@riverpod
Future<List<TransactionEntity>> selectedDateTransactions(
  Ref ref,
  DateTime selectedDate,
) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
  final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
  final filter = TransactionFilter(dateFrom: start, dateTo: end);
  return repo.getFiltered(filter);
}
