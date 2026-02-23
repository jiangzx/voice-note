import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../domain/entities/transaction_entity.dart';

/// Segmented button for expense/income/transfer. Compact style for form/detail.
class TypeSelector extends StatelessWidget {
  const TypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showTransfer = true,
  });

  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;
  /// 为 false 时仅显示支出/收入（如记录详情页）。
  final bool showTransfer;

  @override
  Widget build(BuildContext context) {
    final segments = [
      const ButtonSegment(
        value: TransactionType.expense,
        label: Text('支出'),
        icon: Icon(Icons.arrow_downward_rounded, size: 16),
      ),
      const ButtonSegment(
        value: TransactionType.income,
        label: Text('收入'),
        icon: Icon(Icons.arrow_upward_rounded, size: 16),
      ),
      if (showTransfer)
        const ButtonSegment(
          value: TransactionType.transfer,
          label: Text('转账'),
          icon: Icon(Icons.swap_horiz_rounded, size: 16),
        ),
    ];
    final effectiveSelected = showTransfer
        ? selected
        : (selected == TransactionType.transfer
            ? TransactionType.expense
            : selected);
    return SegmentedButton<TransactionType>(
      segments: segments,
      selected: {effectiveSelected},
      onSelectionChanged: (set) => onChanged(set.first),
      style: const ButtonStyle(
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        ),
        minimumSize: WidgetStatePropertyAll(Size(0, 36)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
