import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';

/// Reusable app drawer: user block, common actions grid, quick-entry grid, settings/feedback.
/// Optional [onUserTap] for future login/profile; when null, user block shows placeholder.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.onUserTap});

  final VoidCallback? onUserTap;

  static const _drawerShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      offset: Offset(2, 0),
      blurRadius: 8,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final surfaceColor = colorScheme.surfaceContainerHighest;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: _drawerShadow,
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            children: [
              _UserBlock(onUserTap: onUserTap),
              const SizedBox(height: AppSpacing.lg),
              const _SectionTitle(title: '常用功能'),
              const SizedBox(height: AppSpacing.sm),
              _CommonActionsGrid(
                onNavigate: (path, usePush) {
                  if (usePush) {
                    AppDrawer._pushAndClose(context, path);
                  } else {
                    AppDrawer._navigateAndClose(context, path);
                  }
                },
                onPlaceholder: () => _showPlaceholderAndClose(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _SectionTitle(title: '快捷记账'),
              const SizedBox(height: AppSpacing.sm),
              _QuickEntryGrid(onPlaceholder: () => _showPlaceholderAndClose(context)),
              const SizedBox(height: AppSpacing.lg),
              _DrawerListTile(
                icon: Icons.settings_outlined,
                title: '设置',
                onTap: () => _navigateAndClose(context, '/settings'),
              ),
              _DrawerListTile(
                icon: Icons.feedback_outlined,
                title: '用户反馈',
                onTap: () => _showPlaceholderAndClose(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _navigateAndClose(BuildContext context, String path) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!context.mounted) return;
    context.go(path);
  }

  /// Push route so back returns to previous page (e.g. home), not settings.
  static void _pushAndClose(BuildContext context, String path) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    if (!context.mounted) return;
    context.push(path);
  }

  static void _showPlaceholderAndClose(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('暂未开放')),
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}

class _UserBlock extends StatelessWidget {
  const _UserBlock({this.onUserTap});

  final VoidCallback? onUserTap;

  @override
  Widget build(BuildContext context) {
    void onTap() {
      if (!context.mounted) return;
      if (onUserTap != null) {
        onUserTap!();
      } else {
        AppDrawer._showPlaceholderAndClose(context);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.backgroundTertiary,
                child: Icon(
                  Icons.person_outline,
                  size: AppIconSize.md,
                  color: AppColors.textPlaceholder,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '匿名用户',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: AppIconSize.md,
                color: AppColors.textPlaceholder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textPlaceholder,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _CommonActionsGrid extends StatelessWidget {
  const _CommonActionsGrid({
    required this.onNavigate,
    required this.onPlaceholder,
  });

  final void Function(String path, bool usePush) onNavigate;
  final VoidCallback onPlaceholder;

  /// (item, path, usePush). usePush true => back goes to previous page (home).
  static const _items = [
    (_DrawerGridItem(Icons.pie_chart_outline, '图表统计'), '/statistics', false),
    (_DrawerGridItem(Icons.menu_book_outlined, '账本管理'), null, false),
    (_DrawerGridItem(Icons.edit_calendar_outlined, '预算管理'), '/settings/budget', true),
    (_DrawerGridItem(Icons.category_outlined, '分类管理'), '/settings/categories', true),
    (_DrawerGridItem(Icons.label_outline, '标签管理'), null, false),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.95,
      children: [
        for (final (item, path, usePush) in _items)
          _GridTile(
            icon: item.icon,
            label: item.label,
            onTap: path != null
                ? () => onNavigate(path, usePush)
                : onPlaceholder,
          ),
      ],
    );
  }
}

class _DrawerGridItem {
  const _DrawerGridItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _QuickEntryGrid extends StatelessWidget {
  const _QuickEntryGrid({required this.onPlaceholder});

  final VoidCallback onPlaceholder;

  static const _items = [
    _DrawerGridItem(Icons.file_upload_outlined, '导入导出'),
    _DrawerGridItem(Icons.auto_awesome_outlined, '自动记账'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.95,
      children: [
        for (final item in _items)
          _GridTile(
            icon: item.icon,
            label: item.label,
            onTap: onPlaceholder,
          ),
      ],
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppIconSize.md, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerListTile extends StatelessWidget {
  const _DrawerListTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: Icon(icon, size: AppIconSize.md, color: AppColors.textSecondary),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          size: AppIconSize.md,
          color: AppColors.textPlaceholder,
        ),
        onTap: onTap,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
  }
}
