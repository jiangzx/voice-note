import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../../../shared/widgets/time_picker_dialog.dart';

/// Quick date selection: today / yesterday + date picker.
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
    final formatter = DateFormat('M/d');
    final selectedDateOnly = selected.toDateOnly;
    final isOtherDate = !selectedDateOnly.isSameDay(today) &&
        !selectedDateOnly.isSameDay(yesterday);

    return Row(
      children: [
        _chip(context, '今天', today),
        const SizedBox(width: AppSpacing.sm),
        _chip(context, '昨天', yesterday),
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
      onSelected: (_) => _pickTimeForDate(context, date),
    );
  }

  Future<void> _pickTimeForDate(BuildContext context, DateTime date) async {
    final initial = DateTime(
      date.year,
      date.month,
      date.day,
      selected.hour,
      selected.minute,
      0,
    );
    final result = await showTimePickerDialog(context, initial: initial);
    if (result != null && context.mounted) onChanged(result);
  }

  Future<void> _pickDate(BuildContext context) async {
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
    if (picked == null || !context.mounted) return;
    final initialTime = DateTime(
      picked.year,
      picked.month,
      picked.day,
      selected.hour,
      selected.minute,
      0,
    );
    final result = await showTimePickerDialog(context, initial: initialTime);
    if (result != null && context.mounted) onChanged(result);
  }
}
