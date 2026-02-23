import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../category/domain/entities/category_entity.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/providers/recent_transactions_paged_provider.dart';
import '../../../transaction/presentation/providers/transaction_form_providers.dart';
import '../../../transaction/presentation/providers/transaction_query_providers.dart';
import '../../../transaction/presentation/utils/group_transactions_by_day.dart';
import '../../../transaction/presentation/widgets/daily_group_header.dart';
import '../widgets/recent_transaction_tile.dart';
import '../widgets/summary_card.dart';
import '../widgets/voice_onboarding_tooltip.dart';

/// Home screen showing monthly summary and recent transactions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _didRequestInitialLoad = false;
  static const double _loadMoreScrollThreshold = 200;

  final ScrollController _scrollController = ScrollController();

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (!position.isScrollingNotifier.value) return;
    if (position.pixels < position.maxScrollExtent - _loadMoreScrollThreshold) return;
    final paged = ref.read(recentTransactionsPagedProvider);
    if (paged.hasMore && !paged.isLoadingMore) {
      ref.read(recentTransactionsPagedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthRange = DateRanges.thisMonth();
    final summaryAsync = ref.watch(
      summaryProvider(monthRange.from, monthRange.to),
    );
    final pagedState = ref.watch(recentTransactionsPagedProvider);
    final incomeCategoriesAsync = ref.watch(visibleCategoriesProvider('income'));
    final expenseCategoriesAsync = ref.watch(visibleCategoriesProvider('expense'));
    final categoryNameMap = <String, String>{};
    final categoryColorMap = <String, Color>{};
    final categoryIconMap = <String, String>{};
    void fillMaps(List<CategoryEntity> cats) {
      for (final cat in cats) {
        categoryNameMap[cat.id] = cat.name;
        categoryColorMap[cat.id] = _parseCategoryColor(cat.color);
        categoryIconMap[cat.id] = cat.icon;
      }
    }
    incomeCategoriesAsync.whenData(fillMaps);
    expenseCategoriesAsync.whenData(fillMaps);

    if (!_didRequestInitialLoad &&
        pagedState.list.isEmpty &&
        !pagedState.isLoading &&
        pagedState.error == null) {
      _didRequestInitialLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(recentTransactionsPagedProvider.notifier).refresh();
      });
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: _isSelectionMode ? _buildSelectionAppBar() : AppBar(title: const Text('快记账')),
        floatingActionButton: _isSelectionMode
            ? const FloatingActionButton(
                onPressed: null,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: SizedBox.shrink(),
              )
            : null,
        body: Stack(
          children: [
            SlidableAutoCloseBehavior(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(recentTransactionsPagedProvider.notifier).refresh(),
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: summaryAsync.when(
                        data: (summary) => SummaryCard(
                          monthLabel: '${monthRange.from.month}月',
                          totalIncome: summary.totalIncome,
                          totalExpense: summary.totalExpense,
                          monthDate: monthRange.from,
                        ),
                        loading: () => ShimmerPlaceholder.card(height: 100),
                        error: (e, st) => ErrorStateWidget(
                          message: '汇总加载失败: $e',
                          onRetry: () => ref.invalidate(
                            summaryProvider(monthRange.from, monthRange.to),
                          ),
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (pagedState.isLoading && pagedState.list.isEmpty)
                      SliverToBoxAdapter(
                        child: ShimmerPlaceholder.listPlaceholder(itemCount: 3),
                      )
                    else if (pagedState.error != null && pagedState.list.isEmpty)
                      SliverToBoxAdapter(
                        child: ErrorStateWidget(
                          message: '加载失败: ${pagedState.error}',
                          onRetry: () =>
                              ref.read(recentTransactionsPagedProvider.notifier).refresh(),
                        ),
                      )
                    else if (pagedState.list.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyStateWidget(
                          icon: Icons.receipt_long_outlined,
                          title: '暂无交易记录',
                          description: '点击右下角 + 开始记账',
                        ),
                      )
                    else
                      ..._buildRecentTransactionsSlivers(
                        context,
                        pagedState,
                        categoryNameMap,
                        categoryColorMap,
                        categoryIconMap,
                        ref,
                      ),
                    if (pagedState.hasMore && pagedState.isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    if (pagedState.hasMore &&
                        !pagedState.isLoadingMore &&
                        pagedState.error != null &&
                        pagedState.list.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          child: Material(
                            color: AppColors.backgroundTertiary,
                            borderRadius: AppRadius.smAll,
                            child: InkWell(
                              onTap: () =>
                                  ref.read(recentTransactionsPagedProvider.notifier).loadMore(),
                              borderRadius: AppRadius.smAll,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: AppIconSize.sm,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      '加载更多失败，点击重试',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const VoiceOnboardingTooltip(),
          ],
        ),
        bottomNavigationBar:
            _isSelectionMode ? _buildSelectionBottomBar(pagedState) : null,
      ),
    );
  }

  List<Widget> _buildRecentTransactionsSlivers(
    BuildContext context,
    RecentTransactionsPagedState pagedState,
    Map<String, String> categoryNameMap,
    Map<String, Color> categoryColorMap,
    Map<String, String> categoryIconMap,
    WidgetRef ref,
  ) {
    final groups = groupTransactionsByDay(pagedState.list);
    var itemCount = 0;
    for (var i = 0; i < groups.length; i++) {
      final n = groups[i].transactions.length;
      itemCount += 1 + 2 * n - 1; // header + n tiles + (n-1) dividers
      if (i < groups.length - 1) itemCount += 1; // 16dp spacer between groups
    }
    const horizontalPadding = 16.0;
    const bottomPadding = 16.0;
    const dividerColor = Color(0xFFE5E7EB);
    final dividerIndent = horizontalPadding + RecentTransactionTile.dividerIndentLeftCol;
    const dividerEndIndent = horizontalPadding;

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, bottomPadding),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              var offset = 0;
              for (var gi = 0; gi < groups.length; gi++) {
                final group = groups[gi];
                final n = group.transactions.length;
                final isLastGroup = gi == groups.length - 1;
                final groupItemCount = 1 + 2 * n - 1 + (isLastGroup ? 0 : 1); // + spacer
                if (index < offset + groupItemCount) {
                  final local = index - offset;
                  if (local == 0) {
                    return DailyGroupHeader(
                      date: group.date,
                      dailyIncome: group.dailyIncome,
                      dailyExpense: group.dailyExpense,
                      showReceiptIcon: true,
                    );
                  }
                  if (!isLastGroup && local == 1 + 2 * n - 1) {
                    return const SizedBox(height: 12);
                  }
                  final tileIndex = (local - 1) ~/ 2;
                  final isDivider = (local - 1) % 2 == 1;
                  if (isDivider) {
                    return Divider(
                      height: 1,
                      thickness: 1,
                      color: dividerColor,
                      indent: dividerIndent,
                      endIndent: dividerEndIndent,
                    );
                  }
                  final tx = group.transactions[tileIndex] as TransactionEntity;
                  final categoryName = tx.categoryId != null
                      ? categoryNameMap[tx.categoryId]
                      : null;
                  final categoryColor = tx.categoryId != null
                      ? categoryColorMap[tx.categoryId]
                      : null;
                  final categoryIconStr = tx.categoryId != null
                      ? categoryIconMap[tx.categoryId]
                      : null;
                  return _TxTileWithCategory(
                    key: ValueKey(tx.id),
                    transaction: tx,
                    isSelectionMode: _isSelectionMode,
                    isSelected: _selectedIds.contains(tx.id),
                    onTap: () => context.push('/record/${tx.id}'),
                    onSelectionChanged: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedIds.add(tx.id);
                        } else {
                          _selectedIds.remove(tx.id);
                        }
                      });
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        setState(() {
                          _isSelectionMode = true;
                          _selectedIds.add(tx.id);
                        });
                      }
                    },
                    categoryName: categoryName,
                    categoryColor: categoryColor,
                    categoryIconStr: categoryIconStr,
                  );
                }
                offset += groupItemCount;
              }
              return const SizedBox.shrink();
            },
            childCount: itemCount,
          ),
        ),
      ),
    ];
  }

  static Color _parseCategoryColor(String hex) {
    final s = hex.replaceFirst(RegExp(r'^#'), '');
    final full = s.length == 6 ? 'FF$s' : s;
    return Color(int.parse(full, radix: 16));
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final count = _selectedIds.length;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        }),
      ),
      title: Text(count > 0 ? '已选择 $count 项' : '选择项目'),
      actions: [
        if (count > 0)
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: '全选/反选',
            onPressed: _toggleSelectAll,
          ),
      ],
    );
  }

  Widget? _buildSelectionBottomBar(RecentTransactionsPagedState pagedState) {
    final count = _selectedIds.length;
    final int totalCount = pagedState.list.length;
    final allSelected = totalCount > 0 && count == totalCount;
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundPrimary,
        boxShadow: AppShadow.card,
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 左侧：全选复选框
            InkWell(
              onTap: _toggleSelectAll,
              borderRadius: AppRadius.mdAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: allSelected,
                      onChanged: (_) => _toggleSelectAll(),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '全选',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // 右侧：操作按钮组
            TextButton(
              onPressed: _exitSelectionMode,
              child: const Text('取消'),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton.icon(
              onPressed: count > 0 ? _handleBatchDelete : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    final list = ref.read(recentTransactionsPagedProvider).list;
    final allIds = list.map((tx) => tx.id).toSet();
    setState(() {
      if (_selectedIds.length == allIds.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allIds);
      }
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 $count 条交易记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final idsToDelete = _selectedIds.toList();
      await repo.deleteBatch(idsToDelete);
      invalidateTransactionQueries(ref);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 $count 条记录'),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }
}

/// Wraps a transaction tile with category lookup.
class _TxTileWithCategory extends ConsumerWidget {
  const _TxTileWithCategory({
    super.key,
    required this.transaction,
    this.categoryName,
    this.categoryColor,
    this.categoryIconStr,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onTap,
    this.onSelectionChanged,
    this.onLongPress,
  });

  final TransactionEntity transaction;
  final String? categoryName;
  final Color? categoryColor;
  final String? categoryIconStr;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? catName = categoryName;
    if (catName == null && transaction.categoryId != null) {
      final type = transaction.type == TransactionType.income
          ? 'income'
          : 'expense';
      final catsAsync = ref.watch(visibleCategoriesProvider(type));
      catName = catsAsync.when(
        data: (cats) {
          final match = cats.where((c) => c.id == transaction.categoryId);
          return match.isNotEmpty ? match.first.name : null;
        },
        loading: () => null,
        error: (e, st) => null,
      );
    }

    return RecentTransactionTile(
      transaction: transaction,
      categoryName: catName,
      categoryColor: categoryColor,
      categoryIconStr: categoryIconStr,
      isSelectionMode: isSelectionMode,
      isSelected: isSelected,
      onTap: onTap,
      onDelete: () => _deleteTransaction(context, ref, transaction.id),
      onSelectionChanged: onSelectionChanged,
      onLongPress: onLongPress,
    );
  }

  void _deleteTransaction(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) {
    try {
      final repo = ref.read(transactionRepositoryProvider);
      repo.delete(id).then((_) {
        invalidateTransactionQueries(ref);
      }).catchError((Object e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败：$e')),
          );
        }
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
    }
  }
}
