import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../app/theme.dart';
import '../../domain/entities/transaction_entity.dart';

/// List tile for a transaction in the transaction list.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.categoryName,
    this.categoryIcon,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onEdit,
    required this.onDelete,
    this.onSelectionChanged,
    this.onLongPress,
  });

  final TransactionEntity transaction;
  final String? categoryName;
  final Widget? categoryIcon;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onLongPress;

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

    final tile = ListTile(
      leading: isSelectionMode
          ? Checkbox(
              value: isSelected,
              onChanged: onSelectionChanged != null
                  ? (value) => onSelectionChanged!(value ?? false)
                  : null,
            )
          : (categoryIcon ??
              CircleAvatar(
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  transaction.type == TransactionType.transfer
                      ? Icons.swap_horiz
                      : Icons.receipt,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )),
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
      onTap: isSelectionMode
          ? () {
              if (onSelectionChanged != null) {
                onSelectionChanged!(!isSelected);
              }
            }
          : onEdit,
      onLongPress: isSelectionMode ? null : onLongPress,
      tileColor: isSelectionMode && isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
    );

    if (isSelectionMode) {
      return tile;
    }

    return Slidable(
      key: ValueKey(transaction.id),
      groupTag: 'transaction-list',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              onDelete();
            },
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete,
            label: '删除',
            borderRadius: BorderRadius.zero,
          ),
        ],
      ),
      child: tile,
    );
  }
}
