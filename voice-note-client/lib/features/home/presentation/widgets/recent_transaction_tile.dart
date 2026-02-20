import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
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
    this.onDelete,
  });

  final TransactionEntity transaction;
  final String? categoryName;
  final Widget? categoryIcon;
  final VoidCallback? onTap;
  final Future<bool> Function()? onDelete;

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

    final tile = ListTile(
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

    if (onDelete == null) {
      return tile;
    }

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmAndDelete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: tile,
    );
  }

  Future<bool> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
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

    if (confirmed != true || onDelete == null) {
      return false;
    }

    try {
      return await onDelete!();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败：$e')),
        );
      }
      return false;
    }
  }
}
