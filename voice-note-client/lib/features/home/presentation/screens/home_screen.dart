import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../budget/presentation/providers/budget_providers.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/providers/transaction_form_providers.dart';
import '../../../transaction/presentation/providers/transaction_query_providers.dart';
import '../widgets/recent_transaction_tile.dart';
import '../widgets/summary_card.dart';
import '../widgets/voice_feature_card.dart';
import '../widgets/voice_onboarding_tooltip.dart';

/// Home screen showing monthly summary and recent transactions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _swipeDeleteHintShown = false;
  static const _keySwipeDeleteHintDismissed = 'home_swipe_delete_hint_dismissed';

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _checkAndShowSwipeDeleteHint();
  }

  Future<void> _checkAndShowSwipeDeleteHint() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_keySwipeDeleteHintDismissed) ?? false;
    if (!dismissed && mounted) {
      setState(() {
        _swipeDeleteHintShown = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthRange = DateRanges.thisMonth();
    final summaryAsync = ref.watch(
      summaryProvider(monthRange.from, monthRange.to),
    );
    final recentAsync = ref.watch(recentTransactionsProvider);

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
              child: ListView(
                children: [
            // Voice feature promotion card
            const VoiceFeatureCard(),

            // Monthly summary card
            summaryAsync.when(
              data: (summary) => SummaryCard(
                totalIncome: summary.totalIncome,
                totalExpense: summary.totalExpense,
              ),
              loading: () => ShimmerPlaceholder.card(height: 100),
              error: (e, st) => ErrorStateWidget(
                message: '汇总加载失败: $e',
                onRetry: () => ref.invalidate(
                  summaryProvider(monthRange.from, monthRange.to),
                ),
              ),
            ),

            // Budget progress summary card
            _BudgetSummaryCard(),

            // Recent transactions header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text('最近交易', style: Theme.of(context).textTheme.titleMedium),
            ),
            if (_swipeDeleteHintShown && !_isSelectionMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: AppRadius.smAll,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.swipe_left,
                      size: AppIconSize.sm,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '左滑可删除',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: AppIconSize.sm),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _swipeDeleteHintShown = false;
                        });
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setBool(_keySwipeDeleteHintDismissed, true);
                        });
                      },
                      tooltip: '关闭',
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),

            // Recent transactions list
            recentAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: '暂无交易记录',
                    description: '点击右下角 + 开始记账',
                  );
                }

                return AnimatedSwitcher(
                  duration: AppDuration.normal,
                  child: Column(
                    key: ValueKey(transactions.length),
                    children: transactions.map((tx) {
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
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => ShimmerPlaceholder.listPlaceholder(itemCount: 3),
              error: (e, st) => ErrorStateWidget(
                message: '加载失败: $e',
                onRetry: () => ref.invalidate(recentTransactionsProvider),
              ),
            ),
                ],
              ),
            ),
            const VoiceOnboardingTooltip(),
          ],
        ),
        bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar(recentAsync) : null,
      ),
    );
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

  Widget? _buildSelectionBottomBar(AsyncValue<List<TransactionEntity>> recentAsync) {
    final count = _selectedIds.length;
    
    // 计算总数量以判断是否全选
    final int totalCount = recentAsync.maybeWhen(
      data: (transactions) => transactions.length,
      orElse: () => 0,
    );
    
    final allSelected = totalCount > 0 && count == totalCount;
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
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
                      style: theme.textTheme.titleMedium,
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
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
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
    final recentAsync = ref.read(recentTransactionsProvider);
    
    recentAsync.whenData((transactions) {
      final allIds = transactions.map((tx) => tx.id).toSet();
      
      setState(() {
        if (_selectedIds.length == allIds.length) {
          _selectedIds.clear();
        } else {
          _selectedIds.addAll(allIds);
        }
      });
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

/// Budget progress summary for the home screen.
class _BudgetSummaryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(budgetSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        if (summary.totalBudget <= 0) return const SizedBox.shrink();

        final pct = (summary.totalSpent / summary.totalBudget * 100)
            .clamp(0.0, 999.9);
        final remaining = summary.totalRemaining;
        final theme = Theme.of(context);
        final isOver = remaining < 0;
        final progressColor = pct >= 100
            ? Colors.red.shade600
            : pct >= 80
                ? Colors.amber.shade700
                : Colors.green.shade600;

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: InkWell(
            borderRadius: AppRadius.mdAll,
            onTap: () => context.push('/settings/budget'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.savings_outlined,
                          size: AppIconSize.sm,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text('本月预算',
                          style: theme.textTheme.titleSmall),
                      const Spacer(),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: progressColor,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '已用 ¥${summary.totalSpent.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        isOver
                            ? '超支 ¥${(-remaining).toStringAsFixed(0)}'
                            : '剩余 ¥${remaining.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isOver ? Colors.red : null,
                          fontWeight: isOver ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Wraps a transaction tile with category lookup.
class _TxTileWithCategory extends ConsumerWidget {
  const _TxTileWithCategory({
    super.key,
    required this.transaction,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onTap,
    this.onSelectionChanged,
    this.onLongPress,
  });

  final TransactionEntity transaction;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? catName;
    if (transaction.categoryId != null) {
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
