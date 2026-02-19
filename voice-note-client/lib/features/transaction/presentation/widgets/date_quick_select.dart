import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/extensions/date_extensions.dart';

/// Quick date selection: today / yesterday / day-before + date picker.
class DateQuickSelect extends StatelessWidget {
  const DateQuickSelect({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toDateOnly;
    final yesterday = today.yesterday;
    final dayBefore = today.dayBeforeYesterday;
    final formatter = DateFormat('M/d');

    return Row(
      children: [
        _chip(context, '今天', today),
        const SizedBox(width: AppSpacing.sm),
        _chip(context, '昨天', yesterday),
        const SizedBox(width: AppSpacing.sm),
        _chip(context, '前天', dayBefore),
        const SizedBox(width: AppSpacing.sm),
        ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(
            selected.isSameDay(today) ? '选择日期' : formatter.format(selected),
          ),
          onPressed: () => _pickDate(context),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, DateTime date) {
    final isSelected = selected.isSameDay(date);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(date),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) onChanged(picked);
  }
}
