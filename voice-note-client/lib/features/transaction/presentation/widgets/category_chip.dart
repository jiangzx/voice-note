import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../category/domain/entities/category_entity.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/icon_utils.dart';

/// Horizontal chip list for recently used categories.
class RecentCategoryChips extends StatelessWidget {
  const RecentCategoryChips({
    super.key,
    required this.categories,
    this.selectedId,
    required this.onSelected,
  });

  final List<CategoryEntity> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            '最近使用',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              final color = colorFromArgbHex(cat.color);
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ActionChip(
                  avatar: iconFromString(cat.icon, size: 18),
                  label: Text(cat.name),
                  onPressed: () => onSelected(cat.id),
                  side: cat.id == selectedId
                      ? BorderSide(color: color, width: 2)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
