import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';

/// List tile for a recent transaction on the home screen.
class RecentTransactionTile extends StatelessWidget {
  const RecentTransactionTile({
    super.key,
    required this.transaction,
    this.categoryName,
    this.categoryIcon,
    this.onTap,
  });

  final TransactionEntity transaction;
  final String? categoryName;
  final Widget? categoryIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txColors = theme.extension<TransactionColors>()!;

    final displayName = transaction.description ?? categoryName ?? '未分类';
    final dateText = DateFormat('M/d').format(transaction.date);

    Color amountColor;
    String amountPrefix;

    switch (transaction.type) {
      case TransactionType.expense:
        amountColor = txColors.expense;
        amountPrefix = '-';
      case TransactionType.income:
        amountColor = txColors.income;
        amountPrefix = '+';
      case TransactionType.transfer:
        amountColor = txColors.transfer;
        amountPrefix =
            transaction.transferDirection == TransferDirection.outbound
            ? '-'
            : '+';
    }

    return ListTile(
      leading:
          categoryIcon ??
          CircleAvatar(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              transaction.type == TransactionType.transfer
                  ? Icons.swap_horiz
                  : Icons.receipt,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(dateText),
      trailing: Text(
        '$amountPrefix¥${transaction.amount.toStringAsFixed(2)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: amountColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
