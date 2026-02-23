import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../domain/models/top_transaction_rank_item.dart';
import '../providers/statistics_providers.dart';

/// 选定时间范围内按金额排序的单笔交易排行（前 10），默认显示 5 条，展开全部可见 10 条。
class SingleTransactionRanking extends ConsumerStatefulWidget {
  const SingleTransactionRanking({super.key});

  @override
  ConsumerState<SingleTransactionRanking> createState() =>
      _SingleTransactionRankingState();
}

class _SingleTransactionRankingState
    extends ConsumerState<SingleTransactionRanking> {
  bool _expanded = false;

  static const int _defaultCount = 5;

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(topTransactionsByAmountProvider);
    final theme = Theme.of(context);
    final txColors = transactionColorsOrFallback(theme);

    return listAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '暂无交易记录',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final visibleCount = _expanded ? list.length : list.length.clamp(0, _defaultCount);
        final hasMore = list.length > _defaultCount && !_expanded;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleCount,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = list[i];
                final isIncome = ref.watch(singleRankingTypeProvider) == 'income';
                return _RankItem(
                  rank: i + 1,
                  item: item,
                  isIncome: isIncome,
                  txColors: txColors,
                  onTap: () => context.push('/record/${item.id}'),
                );
              },
            ),
            if (hasMore)
              InkWell(
                onTap: () => setState(() => _expanded = true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '展开全部',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, st) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '加载失败: $e',
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _RankItem extends StatelessWidget {
  const _RankItem({
    required this.rank,
    required this.item,
    required this.isIncome,
    required this.txColors,
    required this.onTap,
  });

  final int rank;
  final TopTransactionRankItem item;
  final bool isIncome;
  final TransactionColors txColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _parseColor(item.color, txColors.expense);
    final amountColor = isIncome ? txColors.income : txColors.expense;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              child: Text(
                '$rank',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.2),
              child: iconFromString(item.icon, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.categoryName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (item.description != null &&
                      item.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '¥${item.amount.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w600,
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
