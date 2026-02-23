import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../domain/models/daily_breakdown_row.dart';
import '../providers/statistics_providers.dart';

/// 账单汇总：日期 | 支出 | 收入 | 结余，总计，日均/月均。
class BillSummaryTable extends ConsumerWidget {
  const BillSummaryTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdownAsync = ref.watch(dailyBreakdownProvider);
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final range = ref.watch(effectiveDateRangeProvider);
    final days = range.end.difference(range.start).inDays + 1;
    final isYear = periodType == PeriodType.year;
    final avgLabel = isYear ? '月均' : '日均';

    return breakdownAsync.when(
      data: (rows) {
        // 只展示支出或收入至少有一项非 0 的日期
        final filtered = rows
            .where((r) => r.expense != 0 || r.income != 0)
            .toList();
        final totalExpense = filtered.fold<double>(0, (s, r) => s + r.expense);
        final totalIncome = filtered.fold<double>(0, (s, r) => s + r.income);
        final totalBalance = totalIncome - totalExpense;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final txColors = transactionColorsOrFallback(theme);
        final divisor = isYear && days > 28 ? (days / 30).clamp(1.0, 12.0) : days.toDouble();
        final avgE = divisor > 0 ? totalExpense / divisor : 0.0;
        final avgI = divisor > 0 ? totalIncome / divisor : 0.0;
        final avgB = divisor > 0 ? (totalIncome - totalExpense) / divisor : 0.0;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outline, width: 1),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tableHeader(theme),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    '暂无数据',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, endIndent: 12),
                    itemBuilder: (_, i) => _tableRow(context, filtered[i], txColors),
                  ),
                ),
              Divider(height: 1, color: Theme.of(context).colorScheme.outline),
              _totalRow(context, '总计', totalExpense, totalIncome, totalBalance, txColors),
              _totalRow(context, avgLabel, avgE, avgI, avgB, txColors),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          '加载失败: $e',
          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
        ),
      ),
    );
  }

  Widget _tableHeader(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              '日期',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '支出',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              '收入',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              '结余',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(
    BuildContext context,
    DailyBreakdownRow r,
    TransactionColors txColors,
  ) {
    final theme = Theme.of(context);
    final dateStr = r.dateLabel.length >= 10 ? r.dateLabel.substring(5) : r.dateLabel;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              dateStr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _money(r.expense),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: txColors.expense,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _money(r.income),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: txColors.income,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _money(r.balance),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: r.balance >= 0 ? txColors.income : txColors.expense,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    BuildContext context,
    String label,
    double expense,
    double income,
    double balance,
    TransactionColors txColors,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _money(expense),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: txColors.expense,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _money(income),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: txColors.income,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                _money(balance),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: balance >= 0 ? txColors.income : txColors.expense,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _money(double v) {
    return '¥${v.toStringAsFixed(2)}';
  }
}
