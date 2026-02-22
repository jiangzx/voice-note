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
    final now = DateTime.now();
    final today = now.toDateOnly;
    final yesterday = today.yesterday;
    final dayBefore = today.dayBeforeYesterday;
    final formatter = DateFormat('M/d');
    final selectedDateOnly = selected.toDateOnly;
    final isOtherDate = !selectedDateOnly.isSameDay(today) &&
        !selectedDateOnly.isSameDay(yesterday) &&
        !selectedDateOnly.isSameDay(dayBefore);

    return Row(
      children: [
        _chip(context, '今天', today),
        const SizedBox(width: AppSpacing.sm),
        _chip(context, '昨天', yesterday),
        const SizedBox(width: AppSpacing.sm),
        _chip(context, '前天', dayBefore),
        const SizedBox(width: AppSpacing.sm),
        ChoiceChip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(
            isOtherDate ? formatter.format(selectedDateOnly) : '选择日期',
          ),
          selected: isOtherDate,
          onSelected: (_) => _pickDate(context),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, DateTime date) {
    final isSelected = selected.toDateOnly.isSameDay(date);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onChanged(date),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    // Use "now" at picker open so lastDate is correct even near midnight.
    final now = DateTime.now();
    final lastDate = now.toDateOnly;
    final initialDate = selected.toDateOnly.isAfter(lastDate)
        ? lastDate
        : selected;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
    );
    if (picked != null) onChanged(picked);
  }
}
