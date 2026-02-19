import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';

/// Card displaying monthly income and expense summary.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    this.title = '本月收支',
  });

  final double totalIncome;
  final double totalExpense;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txColors = theme.extension<TransactionColors>()!;

    return Card(
      margin: const EdgeInsets.all(AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _SummaryItem(
                    label: '收入',
                    amount: totalIncome,
                    color: txColors.income,
                  ),
                ),
                Expanded(
                  child: _SummaryItem(
                    label: '支出',
                    amount: totalExpense,
                    color: txColors.expense,
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
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
