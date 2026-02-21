import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/date_extensions.dart';

/// Header for a daily transaction group showing date and subtotals.
class DailyGroupHeader extends StatelessWidget {
  const DailyGroupHeader({
    super.key,
    required this.date,
    required this.dailyIncome,
    required this.dailyExpense,
  });

  final DateTime date;
  final double dailyIncome;
  final double dailyExpense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txColors = theme.extension<TransactionColors>()!;
    final today = DateTime.now().toDateOnly;

    String dateLabel;
    if (date.isSameDay(today)) {
      dateLabel = '今天';
    } else if (date.isSameDay(today.yesterday)) {
      dateLabel = '昨天';
    } else {
      dateLabel = DateFormat('M月d日').format(date);
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      color: AppColors.backgroundSecondary,
      child: Row(
        children: [
          Text(
            dateLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (dailyIncome > 0)
            Text(
              '收 ${dailyIncome.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: txColors.income,
              ),
            ),
          if (dailyIncome > 0 && dailyExpense > 0)
            const SizedBox(width: AppSpacing.md),
          if (dailyExpense > 0)
            Text(
              '支 ${dailyExpense.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: txColors.expense,
              ),
            ),
        ],
      ),
    );
  }
}
