import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';

/// Picks hour and minute; returns [DateTime] with same date as [initial], new time (second=0), or null if cancelled.
Future<DateTime?> showTimePickerDialog(
  BuildContext context, {
  required DateTime initial,
}) async {
  int hour = initial.hour;
  int minute = initial.minute;

  return showDialog<DateTime>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('选择时间'),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TimeDropdown(
                  value: hour,
                  items: List.generate(24, (i) => i),
                  label: '时',
                  onChanged: (v) => setState(() => hour = v!),
                ),
                _TimeDropdown(
                  value: minute,
                  items: List.generate(60, (i) => i),
                  label: '分',
                  onChanged: (v) => setState(() => minute = v!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final result = DateTime(
                    initial.year,
                    initial.month,
                    initial.day,
                    hour,
                    minute,
                    0,
                  );
                  Navigator.of(ctx).pop(result);
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final List<int> items;
  final String label;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<int>(
          value: value,
          isDense: true,
          items: items
              .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      v.toString().padLeft(2, '0'),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
