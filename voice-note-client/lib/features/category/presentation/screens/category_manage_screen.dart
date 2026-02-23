import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../core/utils/id_generator.dart' as id_gen;
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/error_copy.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../domain/entities/category_entity.dart';
import '../providers/category_providers.dart';

/// Category management screen with reorder, hide/show, and CRUD.
class CategoryManageScreen extends ConsumerStatefulWidget {
  const CategoryManageScreen({super.key});

  @override
  ConsumerState<CategoryManageScreen> createState() =>
      _CategoryManageScreenState();
}

class _CategoryManageScreenState extends ConsumerState<CategoryManageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentType => _tabController.index == 0 ? 'expense' : 'income';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '支出'),
            Tab(text: '收入'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CategoryList(type: 'expense', ref: ref),
          _CategoryList(type: 'income', ref: ref),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建分类'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '分类名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final repo = ref.read(categoryRepositoryProvider);
              final now = DateTime.now();
              await repo.create(
                CategoryEntity(
                  id: id_gen.generateId(),
                  name: nameController.text.trim(),
                  type: _currentType,
                  icon: 'material:label',
                  color: 'FF607D8B',
                  isPreset: false,
                  isHidden: false,
                  sortOrder: 999,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
              ref.invalidate(visibleCategoriesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.type, required this.ref});

  final String type;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    // Use getAll to show hidden categories too in management
    final repo = ref.watch(categoryRepositoryProvider);

    return FutureBuilder<List<CategoryEntity>>(
      future: repo.getAll(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ShimmerPlaceholder.listPlaceholder(itemCount: 5);
        }
        if (snapshot.hasError) {
          return ErrorStateWidget(message: ErrorCopy.loadFailed);
        }

        final categories = snapshot.data ?? [];
        if (categories.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.category_outlined,
            title: '暂无分类',
          );
        }

        return ReorderableListView.builder(
          itemCount: categories.length,
          onReorder: (oldIndex, newIndex) async {
            if (newIndex > oldIndex) newIndex--;
            final reordered = List<CategoryEntity>.from(categories);
            final item = reordered.removeAt(oldIndex);
            reordered.insert(newIndex, item);
            await repo.reorder(reordered.map((c) => c.id).toList());
            ref.invalidate(visibleCategoriesProvider);
          },
          itemBuilder: (context, index) {
            final cat = categories[index];
            final color = colorFromArgbHex(cat.color);

            return ListTile(
              key: ValueKey(cat.id),
              leading: CircleAvatar(
                backgroundColor: color.withAlpha(25),
                child: iconFromString(cat.icon),
              ),
              title: Text(
                cat.name,
                style: cat.isHidden
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Theme.of(context).colorScheme.outline,
                      )
                    : null,
              ),
              subtitle: Row(
                children: [
                  if (cat.isPreset)
                    Text(
                      '预设',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (cat.isHidden)
                    Text(
                      ' · 已隐藏',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) =>
                    _handleAction(context, action, cat, repo),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle_visibility',
                    child: Text(cat.isHidden ? '显示' : '隐藏'),
                  ),
                  if (!cat.isPreset) ...[
                    const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    CategoryEntity cat,
    dynamic repo,
  ) async {
    switch (action) {
      case 'toggle_visibility':
        await repo.update(cat.copyWith(isHidden: !cat.isHidden));
        ref.invalidate(visibleCategoriesProvider);
      case 'edit':
        _showEditDialog(context, cat, repo);
      case 'delete':
        await _confirmDelete(context, cat, repo);
    }
  }

  void _showEditDialog(BuildContext context, CategoryEntity cat, dynamic repo) {
    final nameController = TextEditingController(text: cat.name);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑分类'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '分类名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await repo.update(cat.copyWith(name: nameController.text.trim()));
              ref.invalidate(visibleCategoriesProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CategoryEntity cat,
    dynamic repo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除"${cat.name}"吗？如果有交易引用该分类，将自动隐藏而非真正删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await repo.delete(cat.id);
      ref.invalidate(visibleCategoriesProvider);
    } on StateError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
