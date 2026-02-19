import 'package:flutter/material.dart';

import '../../domain/entities/transaction_entity.dart';

/// Segmented button for switching between expense/income/transfer.
class TypeSelector extends StatelessWidget {
  const TypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment(
          value: TransactionType.expense,
          label: Text('支出'),
          icon: Icon(Icons.arrow_downward),
        ),
        ButtonSegment(
          value: TransactionType.income,
          label: Text('收入'),
          icon: Icon(Icons.arrow_upward),
        ),
        ButtonSegment(
          value: TransactionType.transfer,
          label: Text('转账'),
          icon: Icon(Icons.swap_horiz),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}
