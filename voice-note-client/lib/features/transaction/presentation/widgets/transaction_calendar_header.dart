import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';

/// Month switcher: < 2026年02月 [回今天] > — 回今天 = rounded pill, white on soft yellow.
class TransactionCalendarHeader extends StatelessWidget {
  const TransactionCalendarHeader({
    super.key,
    required this.currentMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onBackToToday,
  });

  final DateTime currentMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onBackToToday;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('yyyy年MM月').format(currentMonth);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: onPrevMonth,
            tooltip: '上一月',
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
          Semantics(
            label: '回到今天',
            button: true,
            child: Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onBackToToday,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    '回今天',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
            onPressed: onNextMonth,
            tooltip: '下一月',
          ),
        ],
      ),
    );
  }
}
