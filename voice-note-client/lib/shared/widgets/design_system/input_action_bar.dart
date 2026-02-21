import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';

/// Full-width input/action bar: large radius, white background, optional leading/trailing icons, hint.
/// Per spec: 28-32px radius, light bottom shadow, no border.
class InputActionBar extends StatelessWidget {
  const InputActionBar({
    super.key,
    this.leading,
    this.trailing,
    this.hintText,
    this.controller,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  final Widget? leading;
  final Widget? trailing;
  final String? hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: AppRadius.inputAll,
        boxShadow: AppShadow.input,
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        onTap: onTap,
        readOnly: readOnly,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.textPlaceholder,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          prefixIcon: leading != null
              ? Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: AppColors.textPlaceholder,
                      size: AppIconSize.md,
                    ),
                    child: leading!,
                  ),
                )
              : null,
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 24,
          ),
          suffixIcon: trailing != null
              ? Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: AppColors.textPlaceholder,
                      size: AppIconSize.md,
                    ),
                    child: trailing!,
                  ),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 24,
          ),
        ),
      ),
    );
  }
}
