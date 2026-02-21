import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';

/// Primary button: brand fill, white text, capsule shape.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
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
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandPrimary,
        foregroundColor: Colors.white,
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
              data: const IconThemeData(color: Colors.white, size: AppIconSize.sm),
              child: icon!,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(label, style: theme.textTheme.labelLarge?.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}
