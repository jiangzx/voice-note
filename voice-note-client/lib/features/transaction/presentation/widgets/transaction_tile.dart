import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../domain/entities/transaction_entity.dart';

/// List tile for a transaction in the transaction list.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.categoryName,
    this.categoryIcon,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionEntity transaction;
  final String? categoryName;
  final Widget? categoryIcon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txColors = theme.extension<TransactionColors>()!;
    final displayName = transaction.description ?? categoryName ?? '未分类';

    Color amountColor;
    String amountText;

    switch (transaction.type) {
      case TransactionType.expense:
        amountColor = txColors.expense;
        amountText = '-¥${transaction.amount.toStringAsFixed(2)}';
      case TransactionType.income:
        amountColor = txColors.income;
        amountText = '+¥${transaction.amount.toStringAsFixed(2)}';
      case TransactionType.transfer:
        amountColor = txColors.transfer;
        final prefix =
            transaction.transferDirection == TransferDirection.outbound
            ? '转出'
            : '转入';
        amountText = '$prefix ¥${transaction.amount.toStringAsFixed(2)}';
    }

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: ListTile(
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
        subtitle:
            transaction.type == TransactionType.transfer &&
                transaction.counterparty != null
            ? Text(transaction.counterparty!)
            : null,
        trailing: Text(
          amountText,
          style: theme.textTheme.titleSmall?.copyWith(
            color: amountColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: onEdit,
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条交易记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
