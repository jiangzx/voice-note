import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';

/// Card shown when a voice session has ended, offering a restart button.
class SessionEndedCard extends StatelessWidget {
  final int transactionCount;
  final VoidCallback onRestart;

  const SessionEndedCard({
    super.key,
    required this.transactionCount,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: AppIconSize.lg,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            transactionCount > 0
                ? '本次记录了 $transactionCount 笔交易'
                : '会话已结束',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: onRestart,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('开始新一轮'),
          ),
        ],
      ),
    );
  }
}
