import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';

/// Displays the current amount string with animated value transitions.
/// When [focused] is true, shows a focus ring so user sees they are in amount input.
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({
    super.key,
    required this.amountText,
    this.currencySymbol = '¥',
    this.focused = false,
  });

  final String amountText;
  final String currencySymbol;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = amountText.isEmpty ? '0' : amountText;
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            currencySymbol,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: AnimatedSwitcher(
              duration: AppDuration.fast,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Text(
                displayText,
                key: ValueKey(displayText),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (!focused) return content;
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: AppDuration.fast,
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: AppRadius.inputAll,
        border: Border.all(
          color: colorScheme.primary,
          width: 2,
        ),
      ),
      child: content,
    );
  }
}
