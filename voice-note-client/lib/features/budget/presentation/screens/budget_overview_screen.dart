import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/di/database_provider.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../providers/budget_providers.dart';
import '../widgets/budget_progress_bar.dart';

/// Budget overview screen showing totals and per-category progress.
class BudgetOverviewScreen extends ConsumerWidget {
  const BudgetOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(budgetSummaryProvider);
    final statusesAsync = ref.watch(currentMonthBudgetStatusesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('预算管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/settings/budget/edit'),
          ),
        ],
      ),
      body: statusesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.account_balance_wallet_outlined,
              title: '尚未设置预算',
              description: '点击下方按钮创建本月预算',
              actionLabel: '设置预算',
              onAction: () => context.push('/settings/budget/edit'),
            );
          }

          // Build unbudgeted categories list
          final budgetedIds =
              items.map((i) => i.status.categoryId).toSet();
          final categoryDao = ref.watch(categoryDaoProvider);

          return FutureBuilder(
            future: categoryDao.getByType('expense'),
            builder: (context, snapshot) {
              final allCats = snapshot.data ?? [];
              final unbudgeted = allCats
                  .where((c) =>
                      !c.isHidden && !budgetedIds.contains(c.id))
                  .toList();

              return ListView(
                children: [
                  summaryAsync.when(
                    data: (s) => _BudgetSummaryCard(
                      totalBudget: s.totalBudget,
                      totalSpent: s.totalSpent,
                      totalRemaining: s.totalRemaining,
                    ),
                    loading: () => ShimmerPlaceholder.card(height: 100),
                    error: (e, st) => ErrorStateWidget(
                      message: '汇总加载失败: $e',
                      onRetry: () => ref.invalidate(budgetSummaryProvider),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg),
                    child: Text(
                      '分类预算',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...items.map(
                      (item) => _BudgetCategoryTile(item: item)),
                  if (unbudgeted.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg),
                      child: Text(
                        '未设定',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                    ...unbudgeted.map((cat) => _UnbudgetedTile(
                          name: cat.name,
                          icon: cat.icon,
                          color: cat.color,
                        )),
                  ],
                ],
              );
            },
          );
        },
        loading: () => ShimmerPlaceholder.listPlaceholder(itemCount: 5),
        error: (e, st) => ErrorStateWidget(
          message: '加载失败: $e',
          onRetry: () => ref.invalidate(currentMonthBudgetStatusesProvider),
        ),
      ),
    );
  }
}

class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({
    required this.totalBudget,
    required this.totalSpent,
    required this.totalRemaining,
  });

  final double totalBudget;
  final double totalSpent;
  final double totalRemaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.all(AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本月预算', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: '预算总额',
                    amount: totalBudget,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '已消费',
                    amount: totalSpent,
                    color: theme.colorScheme.error,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '剩余',
                    amount: totalRemaining,
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _UnbudgetedTile extends StatelessWidget {
  const _UnbudgetedTile({
    required this.name,
    required this.icon,
    required this.color,
  });

  final String name;
  final String icon;
  final String color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catColor = colorFromArgbHex(color);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: catColor.withAlpha(64),
              child: iconFromString(icon, size: AppIconSize.md),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(name, style: theme.textTheme.titleSmall),
            ),
            Text(
              '未设定',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCategoryTile extends StatelessWidget {
  const _BudgetCategoryTile({required this.item});

  final BudgetStatusWithCategory item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromArgbHex(item.color);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withAlpha(64),
                  child: iconFromString(item.icon, size: AppIconSize.md),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.status.categoryName,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '¥${item.status.spentAmount.toStringAsFixed(0)} / ¥${item.status.budgetAmount.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            BudgetProgressBar(status: item.status),
          ],
        ),
      ),
    );
  }
}
