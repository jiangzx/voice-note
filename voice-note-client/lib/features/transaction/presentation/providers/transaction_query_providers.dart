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
