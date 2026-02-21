import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';

/// Secondary button: tertiary background, dark text, no border, capsule.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  final String label;
  final Widget? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.backgroundTertiary,
        foregroundColor: AppColors.textPrimary,
        side: BorderSide.none,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            IconTheme.merge(
              data: const IconThemeData(
                color: AppColors.textPrimary,
                size: AppIconSize.sm,
              ),
              child: icon!,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
