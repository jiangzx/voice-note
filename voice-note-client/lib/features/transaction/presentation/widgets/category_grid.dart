import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../../category/domain/entities/category_entity.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/icon_utils.dart';

/// Grid layout for selecting a category.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    this.selectedId,
    required this.onSelected,
    this.recommendedNames = const [],
  });

  final List<CategoryEntity> categories;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final List<String> recommendedNames;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Center(child: Text('暂无分类'));
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = cat.id == selectedId;
        final isRecommended = recommendedNames.contains(cat.name);
        return _CategoryItem(
          category: cat,
          isSelected: isSelected,
          isRecommended: isRecommended,
          onTap: () => onSelected(cat.id),
        );
      },
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.category,
    required this.isSelected,
    required this.isRecommended,
    required this.onTap,
  });

  final CategoryEntity category;
  final bool isSelected;
  final bool isRecommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromArgbHex(category.color);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.lgAll,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.lgAll,
          color: isSelected ? color.withAlpha(30) : Colors.transparent,
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  backgroundColor: color.withAlpha(25),
                  child: iconFromString(category.icon),
                ),
                if (isRecommended)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.schedule,
                        size: 10,
                        color: theme.colorScheme.onTertiary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              category.name,
              style: theme.textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
