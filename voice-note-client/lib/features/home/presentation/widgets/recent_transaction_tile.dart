import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
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
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onTap,
    this.onDelete,
    this.onSelectionChanged,
    this.onLongPress,
  });

  final TransactionEntity transaction;
  final String? categoryName;
  final Widget? categoryIcon;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onLongPress;

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
      subtitle: Text(dateText),
      trailing: Text(
        '$amountPrefix¥${transaction.amount.toStringAsFixed(2)}',
        style: theme.textTheme.titleMedium?.copyWith(
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
          : onTap,
      onLongPress: isSelectionMode ? null : onLongPress,
      tileColor: isSelectionMode && isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
    );

    if (isSelectionMode) {
      return tile;
    }

    if (onDelete == null) {
      return tile;
    }

    return Slidable(
      key: ValueKey(transaction.id),
      groupTag: 'recent-transactions',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              onDelete?.call();
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
