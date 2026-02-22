import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../domain/models/budget_status.dart';

/// Horizontal progress bar showing budget consumption with color coding.
/// Green (0-79%), yellow (80-99%), red (100%+).
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.status,
    this.height = 12,
  });

  final BudgetStatus status;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = status.percentage.clamp(0.0, 100.0) / 100;
    final exceeded = status.percentage >= 100;
    final progress = exceeded ? 1.0 : pct;

    final colors = _colorsForLevel(status.level, theme);
    final gradient = LinearGradient(
      colors: colors,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return ClipRRect(
      borderRadius: AppRadius.smAll,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // Background track
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: AppRadius.smAll,
              ),
            ),
            // Progress fill with gradient
            FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: AppRadius.smAll,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _colorsForLevel(BudgetLevel level, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    switch (level) {
      case BudgetLevel.normal:
        final green = isDark ? Colors.green.shade400 : Colors.green.shade600;
        return [green.withValues(alpha: 0.8), green];
      case BudgetLevel.warning:
        final amber = isDark ? Colors.amber.shade400 : Colors.amber.shade700;
        return [amber.withValues(alpha: 0.8), amber];
      case BudgetLevel.exceeded:
        final red = isDark ? Colors.red.shade400 : Colors.red.shade700;
        return [red.withValues(alpha: 0.8), red];
    }
  }
}

/// Wrapper to apply width factor to child (for gradient progress).
class FractionallySizedBox extends StatelessWidget {
  const FractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
  });

  final double widthFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth * widthFactor,
          child: child,
        );
      },
    );
  }
}
