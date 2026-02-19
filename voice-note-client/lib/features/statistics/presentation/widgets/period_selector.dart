import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../providers/statistics_providers.dart';

/// Row with left/right arrows and center period label, plus segmented period type.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final date = ref.watch(selectedDateProvider);
    final label = _formatPeriodLabel(date, periodType);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _navigatePeriod(ref, -1),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _navigatePeriod(ref, 1),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<PeriodType>(
          segments: const [
            ButtonSegment(value: PeriodType.day, label: Text('日')),
            ButtonSegment(value: PeriodType.week, label: Text('周')),
            ButtonSegment(value: PeriodType.month, label: Text('月')),
            ButtonSegment(value: PeriodType.year, label: Text('年')),
          ],
          selected: {periodType},
          onSelectionChanged: (Set<PeriodType> selected) {
            ref.read(selectedPeriodTypeProvider.notifier).state =
                selected.first;
          },
        ),
      ],
    );
  }

  String _formatPeriodLabel(DateTime date, PeriodType type) {
    switch (type) {
      case PeriodType.day:
        return DateFormat('yyyy年M月d日').format(date);
      case PeriodType.week:
        final monday = date.subtract(Duration(days: date.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return '${DateFormat('M/d').format(monday)} - ${DateFormat('M/d').format(sunday)}';
      case PeriodType.month:
        return DateFormat('yyyy年M月').format(date);
      case PeriodType.year:
        return DateFormat('yyyy年').format(date);
    }
  }

  void _navigatePeriod(WidgetRef ref, int delta) {
    final periodType = ref.read(selectedPeriodTypeProvider);
    final date = ref.read(selectedDateProvider);

    DateTime newDate;
    switch (periodType) {
      case PeriodType.day:
        newDate = date.add(Duration(days: delta));
      case PeriodType.week:
        newDate = date.add(Duration(days: 7 * delta));
      case PeriodType.month:
        newDate = DateTime(date.year, date.month + delta, date.day);
      case PeriodType.year:
        newDate = DateTime(date.year + delta, date.month, date.day);
    }

    ref.read(selectedDateProvider.notifier).state = newDate;
  }
}
