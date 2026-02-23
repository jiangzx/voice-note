import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/extensions/date_extensions.dart';
import '../../domain/entities/transaction_filter.dart';

const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

/// Calendar card: light grey, rounded, slight elevation (per prototype).
const _kCalendarCardBg = Color(0xFFF3F4F6);
const _kWeekdayPillBlue = Color(0xFF93C5FD);
const _kTodayYellow = Color(0xFFE6C229);
const _kSundayGrey = Color(0xFF9CA3AF);

/// Map from date (day-only) to daily income/expense for calendar cells.
Map<DateTime, ({double income, double expense})> _groupMap(
  List<DailyTransactionGroup> groups,
) {
  final map = <DateTime, ({double income, double expense})>{};
  for (final g in groups) {
    final key = DateTime(g.date.year, g.date.month, g.date.day);
    map[key] = (income: g.dailyIncome, expense: g.dailyExpense);
  }
  return map;
}

/// Calendar grid: optional month header + weekdays row + month days; each cell shows day number, +income, -expense.
/// When [monthHeader] is set, it is shown inside the same card (per prototype: one card for full calendar).
class TransactionCalendarGrid extends StatelessWidget {
  const TransactionCalendarGrid({
    super.key,
    this.monthHeader,
    required this.currentMonth,
    required this.selectedDate,
    required this.dailyGroups,
    required this.onSelectDate,
  });

  /// Optional header (month + arrows + 回今天) to show inside the calendar card.
  final Widget? monthHeader;
  final DateTime currentMonth;
  final DateTime selectedDate;
  final List<DailyTransactionGroup> dailyGroups;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final summaryMap = _groupMap(dailyGroups);
    final first = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1;
    final today = DateTime.now().toDateOnly;
    final selectedDayOnly = selectedDate.toDateOnly;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Material(
        color: _kCalendarCardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (monthHeader != null) monthHeader!,
              if (monthHeader != null) const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _weekdays
                    .map((w) => Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _kWeekdayPillBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            w,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.9,
                children: [
                  ...List.generate(leadingBlanks, (_) => const SizedBox.shrink()),
                  ...List.generate(lastDay, (i) {
                    final date = DateTime(currentMonth.year, currentMonth.month, i + 1);
                    final sum = summaryMap[date] ?? (income: 0.0, expense: 0.0);
                    final isSelected = date.isSameDay(selectedDayOnly);
                    final isToday = date.isSameDay(today);
                    final isSunday = date.weekday == DateTime.sunday;
                    return _DayCell(
                      day: i + 1,
                      income: sum.income,
                      expense: sum.expense,
                      isSelected: isSelected,
                      isToday: isToday,
                      isSunday: isSunday,
                      onTap: () => onSelectDate(date),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.income,
    required this.expense,
    required this.isSelected,
    required this.isToday,
    required this.isSunday,
    required this.onTap,
  });

  final int day;
  final double income;
  final double expense;
  final bool isSelected;
  final bool isToday;
  final bool isSunday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incomeStr = income > 0 ? '+${NumberFormat.currency(locale: 'zh_CN', symbol: '', decimalDigits: 2).format(income)}' : '';
    final expenseStr = expense > 0 ? '-${NumberFormat.currency(locale: 'zh_CN', symbol: '', decimalDigits: 2).format(expense)}' : '';

    final bool useTodayStyle = isToday;
    final Color cellBg = useTodayStyle ? _kTodayYellow : Colors.white;
    final Color dayColor = useTodayStyle ? Colors.white : (isSunday ? _kSundayGrey : AppColors.textPrimary);
    final Color borderColor = isSelected && !useTodayStyle ? AppColors.brandPrimary.withValues(alpha: 0.4) : const Color(0xFFE5E7EB);

    return Material(
      color: cellBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isSelected && !useTodayStyle ? Border.all(color: borderColor, width: 1.5) : null,
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isToday ? '今' : '$day',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                        color: dayColor,
                      ),
                    ),
                    if (incomeStr.isNotEmpty || expenseStr.isNotEmpty)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (incomeStr.isNotEmpty)
                                  Text(
                                    incomeStr,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.income,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (expenseStr.isNotEmpty)
                                  Text(
                                    expenseStr,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.expense,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
