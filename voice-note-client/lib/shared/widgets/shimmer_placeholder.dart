import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/design_tokens.dart';

/// Shimmer placeholder for loading states.
class ShimmerPlaceholder extends StatelessWidget {
  const ShimmerPlaceholder({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: child,
    );
  }

  /// Card-shaped placeholder.
  static Widget card({double height = 80}) {
    return _ThemeAwareShimmer(
      builder: (maskColor) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: maskColor,
            borderRadius: AppRadius.mdAll,
          ),
        ),
      ),
    );
  }

  /// List-item shaped placeholder.
  static Widget listItem() {
    return _ThemeAwareShimmer(
      builder: (maskColor) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: maskColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: maskColor,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(height: 10, width: 120, color: maskColor),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(height: 14, width: 60, color: maskColor),
          ],
        ),
      ),
    );
  }

  /// Multiple list items as a loading list placeholder.
  static Widget listPlaceholder({int itemCount = 5}) {
    return Column(children: List.generate(itemCount, (_) => listItem()));
  }

  /// Card + list combo for home screen loading.
  static Widget homeScreenPlaceholder() {
    return Column(
      children: [
        card(height: 100),
        const SizedBox(height: AppSpacing.lg),
        ...List.generate(3, (_) => listItem()),
      ],
    );
  }
}

/// Provides a theme-aware mask color for shimmer child shapes.
class _ThemeAwareShimmer extends StatelessWidget {
  const _ThemeAwareShimmer({required this.builder});

  final Widget Function(Color maskColor) builder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maskColor = isDark ? Colors.grey.shade700 : Colors.white;
    return ShimmerPlaceholder(child: builder(maskColor));
  }
}
