import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../providers/statistics_providers.dart';

/// 时间范围：周 | 月 | 年 | 自定义；选择后显示 < 2026年2月 > 或自定义区间。
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  static const _borderColor = Color(0xFFEBEDF0);
  static const _radius = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final date = ref.watch(selectedDateProvider);
    final custom = ref.watch(customDateRangeProvider);
    final label = _formatPeriodLabel(date, periodType, custom);
    final isCustom = periodType == PeriodType.custom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 周 | 月 | 年 | 自定义
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: _borderColor),
            boxShadow: AppShadow.card,
          ),
          child: Row(
            children: [
              _segment(context, ref, PeriodType.week, '周', periodType),
              _segment(context, ref, PeriodType.month, '月', periodType),
              _segment(context, ref, PeriodType.year, '年', periodType),
              _segment(context, ref, PeriodType.custom, '自定义', periodType),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // < 2026年 2 月 >
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left_rounded,
                color: isCustom ? AppColors.textPlaceholder : AppColors.textPrimary,
              ),
              onPressed: isCustom ? null : () => _navigatePeriod(ref, -1),
            ),
            GestureDetector(
              onTap: isCustom ? () => _pickCustomRange(context, ref) : null,
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                color: isCustom ? AppColors.textPlaceholder : AppColors.textPrimary,
              ),
              onPressed: isCustom ? null : () => _navigatePeriod(ref, 1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _segment(
    BuildContext context,
    WidgetRef ref,
    PeriodType value,
    String label,
    PeriodType selected,
  ) {
    final isSelected = value == selected;
    final isCustom = value == PeriodType.custom;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          if (isCustom) {
            final picked = await _pickCustomRange(context, ref);
            if (context.mounted && picked) {
              ref.read(selectedPeriodTypeProvider.notifier).state = PeriodType.custom;
            }
          } else {
            ref.read(selectedPeriodTypeProvider.notifier).state = value;
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.brandPrimary.withValues(alpha: 0.12)
                : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.brandPrimary : AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPeriodLabel(DateTime date, PeriodType type, DateTimeRange? custom) {
    switch (type) {
      case PeriodType.week:
        final monday = date.subtract(Duration(days: date.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        return '${DateFormat('M/d').format(monday)} - ${DateFormat('M/d').format(sunday)}';
      case PeriodType.month:
        return DateFormat('yyyy年M月').format(date);
      case PeriodType.year:
        return DateFormat('yyyy年').format(date);
      case PeriodType.custom:
        if (custom == null) return '选择日期范围';
        return '${DateFormat('M/d').format(custom.start)} - ${DateFormat('M/d').format(custom.end)}';
    }
  }

  /// Returns true if user confirmed a range.
  Future<bool> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final initial = ref.read(customDateRangeProvider) ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.brandPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      ref.read(customDateRangeProvider.notifier).state = picked;
      return true;
    }
    return false;
  }

  void _navigatePeriod(WidgetRef ref, int delta) {
    final periodType = ref.read(selectedPeriodTypeProvider);
    final date = ref.read(selectedDateProvider);

    DateTime newDate;
    switch (periodType) {
      case PeriodType.week:
        newDate = date.add(Duration(days: 7 * delta));
        break;
      case PeriodType.month:
        newDate = DateTime(date.year, date.month + delta, date.day);
        break;
      case PeriodType.year:
        newDate = DateTime(date.year + delta, date.month, date.day);
        break;
      case PeriodType.custom:
        return;
    }
    ref.read(selectedDateProvider.notifier).state = newDate;
  }
}
