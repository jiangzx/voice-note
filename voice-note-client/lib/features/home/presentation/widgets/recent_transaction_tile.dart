import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';

/// Enterprise-style: compact row, clear typography hierarchy, 4px grid.
const _kItemPaddingV = 10.0;
const _kLeftColWidth = 40.0;
const _kGapLeftCenter = 10.0;
const _kChipRadius = 6.0;
const _kChipIconSize = 16.0;
const _kChipPadding = 6.0;
const _kNoteFontSize = 14.0;
const _kNoteFontWeight = FontWeight.w500;
const _kNoteColor = Color(0xFF111827);
const _kNoteLetterSpacing = 0.1;
const _kAuxFontSize = 11.0;
const _kAuxFontWeight = FontWeight.w400;
const _kAuxColor = Color(0xFF6B7280);
const _kAuxNoteGap = 2.0;
const _kAmountFontSize = 15.0;
const _kAmountFontWeight = FontWeight.w600;
const _kAmountLetterSpacing = -0.2;
const _kTransferChipBg = Color(0xFFF3F4F6);
const _kTransferChipFg = Color(0xFF6B7280);

/// List tile for a recent transaction: 3-col layout, category chip (icon+name), note+aux, amount.
class RecentTransactionTile extends StatelessWidget {
  const RecentTransactionTile({
    super.key,
    required this.transaction,
    this.categoryName,
    this.categoryColor,
    this.categoryIconStr,
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
  final Color? categoryColor;
  final String? categoryIconStr;
  final Widget? categoryIcon;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onLongPress;

  /// Left column width + gap used by home list for divider indent.
  static double get dividerIndentLeftCol => _kLeftColWidth + _kGapLeftCenter;

  @override
  Widget build(BuildContext context) {
    final txColors = Theme.of(context).extension<TransactionColors>()!;
    final displayName = transaction.description ?? categoryName ?? '未分类';
    final subtitleText = categoryName ??
        (transaction.type == TransactionType.transfer ? '转账' : '未分类');

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
        amountColor = transaction.transferDirection == TransferDirection.outbound
            ? txColors.expense
            : txColors.income;
        amountPrefix = transaction.transferDirection == TransferDirection.outbound
            ? '-'
            : '+';
    }

    final timeStr = DateFormat('HH:mm').format(transaction.date);
    final auxLine = subtitleText != '未分类' && subtitleText != '转账'
        ? '$timeStr · $subtitleText'
        : timeStr;

    final isTransfer = transaction.type == TransactionType.transfer;
    final chipBg = isTransfer || categoryColor == null
        ? _kTransferChipBg
        : categoryColor!.withValues(alpha: 0.15);
    final chipFg = isTransfer || categoryColor == null
        ? _kTransferChipFg
        : categoryColor!;

    Widget leftCol;
    if (isSelectionMode) {
      leftCol = SizedBox(
        width: _kLeftColWidth,
        child: Center(
          child: Checkbox(
            value: isSelected,
            onChanged: onSelectionChanged != null
                ? (value) => onSelectionChanged!(value ?? false)
                : null,
          ),
        ),
      );
    } else {
      final hasIconStr = categoryIconStr != null && categoryIconStr!.isNotEmpty;
      final leadingIcon = categoryIcon ??
          (hasIconStr
              ? IconTheme(
                  data: IconThemeData(
                    size: _kChipIconSize,
                    color: chipFg,
                  ),
                  child: iconFromString(categoryIconStr!, size: _kChipIconSize),
                )
              : Icon(
                  transaction.type == TransactionType.transfer
                      ? Icons.swap_horiz
                      : Icons.receipt_long_outlined,
                  size: _kChipIconSize,
                  color: chipFg,
                ));
      leftCol = SizedBox(
        width: _kLeftColWidth,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(_kChipPadding),
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(_kChipRadius),
            ),
            child: leadingIcon,
          ),
        ),
      );
    }

    final centerCol = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: _kNoteFontSize,
              fontWeight: _kNoteFontWeight,
              color: _kNoteColor,
              letterSpacing: _kNoteLetterSpacing,
            ),
          ),
          const SizedBox(height: _kAuxNoteGap),
          Text(
            auxLine,
            style: const TextStyle(
              fontSize: _kAuxFontSize,
              fontWeight: _kAuxFontWeight,
              color: _kAuxColor,
            ),
          ),
        ],
      ),
    );

    final rightCol = Text(
      '$amountPrefix¥${transaction.amount.toStringAsFixed(2)}',
      style: TextStyle(
        fontSize: _kAmountFontSize,
        fontWeight: _kAmountFontWeight,
        color: amountColor,
        letterSpacing: _kAmountLetterSpacing,
      ),
    );

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: _kItemPaddingV),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leftCol,
          const SizedBox(width: _kGapLeftCenter),
          centerCol,
          const SizedBox(width: _kGapLeftCenter),
          rightCol,
        ],
      ),
    );

    final tile = Material(
      color: isSelectionMode && isSelected
          ? AppColors.brandPrimary.withValues(alpha: 0.12)
          : null,
      child: InkWell(
        onTap: isSelectionMode
            ? () {
                if (onSelectionChanged != null) {
                  onSelectionChanged!(!isSelected);
                }
              }
            : onTap,
        onLongPress: isSelectionMode ? null : onLongPress,
        child: row,
      ),
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
                      onDelete?.call();
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
