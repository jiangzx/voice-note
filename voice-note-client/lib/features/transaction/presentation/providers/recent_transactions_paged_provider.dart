import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/entities/transaction_entity.dart';
import 'transaction_form_providers.dart';

part 'recent_transactions_paged_provider.g.dart';

const int recentTransactionsPageSize = 20;

/// State for the home-screen recent transactions paged list.
class RecentTransactionsPagedState {
  final List<TransactionEntity> list;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;

  const RecentTransactionsPagedState({
    this.list = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  RecentTransactionsPagedState copyWith({
    List<TransactionEntity>? list,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
  }) {
    return RecentTransactionsPagedState(
      list: list ?? this.list,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

@Riverpod(keepAlive: true)
class RecentTransactionsPaged extends _$RecentTransactionsPaged {
  @override
  RecentTransactionsPagedState build() => const RecentTransactionsPagedState();

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
    );
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final page = await repo.getRecentPage(
        recentTransactionsPageSize,
        0,
      );
      state = state.copyWith(
        list: page,
        hasMore: page.length >= recentTransactionsPageSize,
        isLoading: false,
        isLoadingMore: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e,
      );
      rethrow;
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    final offset = state.list.length;
    state = state.copyWith(isLoadingMore: true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final page = await repo.getRecentPage(
        recentTransactionsPageSize,
        offset,
      );
      if (state.list.length != offset) {
        state = state.copyWith(isLoadingMore: false);
        return;
      }
      state = state.copyWith(
        list: [...state.list, ...page],
        hasMore: page.length >= recentTransactionsPageSize,
        isLoadingMore: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        error: e,
      );
      rethrow;
    }
  }
}
