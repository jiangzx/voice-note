import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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
    // 首页已按日期分组，副标题显示分类更实用
    final subtitleText = categoryName ??
        (transaction.type == TransactionType.transfer ? '转账' : '未分类');

    // 统一两种颜色：支出/转出用 expense，收入/转入用 income
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
        amountColor =
            transaction.transferDirection == TransferDirection.outbound
            ? txColors.expense
            : txColors.income;
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
      subtitle: Text(
        subtitleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
      ),
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
          ? AppColors.brandPrimary.withValues(alpha: 0.12)
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
            backgroundColor: AppColors.expense,
            foregroundColor: Colors.white,
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
