import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../budget/presentation/providers/budget_providers.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/providers/transaction_query_providers.dart';
import '../widgets/recent_transaction_tile.dart';
import '../widgets/summary_card.dart';
import '../widgets/voice_feature_card.dart';
import '../widgets/voice_onboarding_tooltip.dart';

/// Home screen showing monthly summary and recent transactions.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthRange = DateRanges.thisMonth();
    final summaryAsync = ref.watch(
      summaryProvider(monthRange.from, monthRange.to),
    );
    final recentAsync = ref.watch(recentTransactionsProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text('随口记')),
        body: Stack(
          children: [
            ListView(
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
                        onTap: () => context.push('/record/${tx.id}'),
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
            const VoiceOnboardingTooltip(),
          ],
        ),
      ),
    );
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
  const _TxTileWithCategory({super.key, required this.transaction, this.onTap});

  final TransactionEntity transaction;
  final VoidCallback? onTap;

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
      onTap: onTap,
    );
  }
}
