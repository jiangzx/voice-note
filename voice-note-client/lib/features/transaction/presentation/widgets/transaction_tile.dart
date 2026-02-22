import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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

    // 统一为两种颜色：支出/转出用 expense，收入/转入用 income；金额格式 ±¥xx
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
        if (transaction.transferDirection == TransferDirection.outbound) {
          amountColor = txColors.expense;
          amountText = '-¥${transaction.amount.toStringAsFixed(2)}';
        } else {
          amountColor = txColors.income;
          amountText = '+¥${transaction.amount.toStringAsFixed(2)}';
        }
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
                backgroundColor: AppColors.backgroundTertiary,
                radius: AppIconSize.md / 2,
                child: Icon(
                  transaction.type == TransactionType.transfer
                      ? Icons.swap_horiz
                      : Icons.receipt_long_outlined,
                  size: AppIconSize.sm,
                  color: AppColors.textSecondary,
                ),
              )),
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
      ),
      subtitle:
          transaction.type == TransactionType.transfer &&
              transaction.counterparty != null
          ? Text(
              transaction.counterparty!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            )
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
          ? AppColors.brandPrimary.withValues(alpha: 0.12)
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
        extentRatio: 0.2,
        children: [
          Flexible(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Material(
                  color: AppColors.expense,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onDelete();
                    },
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: tile,
    );
  }
}
