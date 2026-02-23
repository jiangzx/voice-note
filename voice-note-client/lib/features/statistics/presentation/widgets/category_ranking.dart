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
          separatorBuilder: (context, index) => const Divider(
            height: 1,
            color: Color(0xFFEBEDF0),
          ),
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
    final percentText = _formatPercent(category.percentage);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.2),
              child: iconFromString(category.icon, size: AppIconSize.sm),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.categoryName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        percentText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: AppRadius.smAll,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 76,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '¥${category.totalAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: amountColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${category.transactionCount}笔',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// 大占比显示 100%，零占比显示 0%，极小正占比显示 <0.1% 避免有金额却显示 0% 的误解。
  static String _formatPercent(double value) {
    if (value >= 99.95) return '100%';
    if (value <= 0) return '0%';
    if (value < 0.05) return '<0.1%';
    return '${value.toStringAsFixed(1)}%';
  }

  Color _parseColor(String hex, Color fallback) {
    try {
      return colorFromArgbHex(hex);
    } catch (_) {
      return fallback;
    }
  }
}
