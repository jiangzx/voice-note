import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../domain/models/category_summary.dart';
import '../providers/statistics_providers.dart';

/// ListView of category items with icon, name, amount, percentage bar.
class CategoryRanking extends ConsumerWidget {
  const CategoryRanking({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categorySummaryProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '暂无分类数据',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }
        final type = ref.watch(categorySummaryTypeProvider);
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, i) => _CategoryRankItem(
            category: categories[i],
            maxAmount: categories
                .map((c) => c.totalAmount)
                .reduce((a, b) => a > b ? a : b),
            isIncome: type == 'income',
            onTap: () => _navigateToTransactions(context, ref, categories[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('加载失败: $e'),
      ),
    );
  }

  void _navigateToTransactions(
    BuildContext context,
    WidgetRef ref,
    CategorySummary category,
  ) {
    if (category.categoryId == '_other') return;
    final range = ref.read(effectiveDateRangeProvider);
    final from = range.start.toIso8601String();
    final to = range.end.toIso8601String();
    context.go(
      '/transactions?categoryId=${category.categoryId}&dateFrom=$from&dateTo=$to',
    );
  }
}

class _CategoryRankItem extends StatelessWidget {
  const _CategoryRankItem({
    required this.category,
    required this.maxAmount,
    required this.isIncome,
    required this.onTap,
  });

  final CategorySummary category;
  final double maxAmount;
  final bool isIncome;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txColors = theme.extension<TransactionColors>()!;
    final color = _parseColor(category.color, txColors.expense);
    final progress = maxAmount > 0 ? category.totalAmount / maxAmount : 0.0;
    final amountColor = isIncome ? txColors.income : txColors.expense;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: iconFromString(category.icon, size: AppIconSize.md),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${category.categoryName} ${category.percentage.toStringAsFixed(2)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: AppRadius.smAll,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '¥${category.totalAmount.toStringAsFixed(2)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${category.transactionCount}笔',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex, Color fallback) {
    try {
      return colorFromArgbHex(hex);
    } catch (_) {
      return fallback;
    }
  }
}
