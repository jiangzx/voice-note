import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/fab_toggle_button.dart';
import '../../../export/presentation/widgets/export_options_sheet.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_filter.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../providers/transaction_form_providers.dart';
import '../providers/transaction_query_providers.dart';
import '../widgets/daily_group_header.dart';
import '../widgets/filter_bar.dart';
import '../widgets/transaction_tile.dart';

/// Screen showing transactions grouped by day with filters.
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({
    super.key,
    this.filterCategoryId,
    this.filterDateFrom,
    this.filterDateTo,
  });

  /// Pre-applied category filter from route query params.
  final String? filterCategoryId;

  /// Pre-applied date range start (ISO 8601) from route query params.
  final String? filterDateFrom;

  /// Pre-applied date range end (ISO 8601) from route query params.
  final String? filterDateTo;

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  DateRangePreset _datePreset = DateRangePreset.thisMonth;
  String? _typeFilter;
  String _searchQuery = '';
  String? _categoryFilter;
  DateTime? _customDateFrom;
  DateTime? _customDateTo;

  // Selection mode state
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = <String>{};
  bool _deleteHintShown = false;
  bool _swipeDeleteHintShown = false;

  static const _keyDeleteHintShown = 'transaction_list_delete_hint_shown';
  static const _keySwipeDeleteHintDismissed = 'transaction_list_swipe_delete_hint_dismissed';

  @override
  void initState() {
    super.initState();
    _categoryFilter = widget.filterCategoryId;
    if (widget.filterDateFrom != null || widget.filterDateTo != null) {
      _customDateFrom = DateTime.tryParse(widget.filterDateFrom ?? '');
      _customDateTo = DateTime.tryParse(widget.filterDateTo ?? '');
      if (_customDateFrom != null || _customDateTo != null) {
        _datePreset = DateRangePreset.custom;
      }
    }
    _checkAndShowDeleteHint();
    _checkAndShowSwipeDeleteHint();
  }

  Future<void> _checkAndShowSwipeDeleteHint() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_keySwipeDeleteHintDismissed) ?? false;
    if (!dismissed && mounted) {
      setState(() {
        _swipeDeleteHintShown = true;
      });
    }
  }

  Future<void> _checkAndShowDeleteHint() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_keyDeleteHintShown) ?? false;
    if (!shown && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_deleteHintShown) {
          _showDeleteHint();
        }
      });
    }
  }

  void _showDeleteHint() {
    if (_deleteHintShown) return;
    _deleteHintShown = true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.info_outline,
              color: AppColors.textPrimary,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('长按项目可进入批量操作模式'),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.2,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
        ),
      ),
    );

    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(_keyDeleteHintShown, true);
    });
  }

  void _showExportSheet(
    BuildContext context,
    ({DateTime from, DateTime to}) dateRange,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExportOptionsSheet(
        initialDateFrom: dateRange.from,
        initialDateTo: dateRange.to,
        initialType: _typeFilter,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _datePreset == DateRangePreset.custom
        ? (
            from: _customDateFrom ?? DateTime(2000),
            to: _customDateTo ?? DateTime(2099),
          )
        : resolveDateRange(_datePreset);
    final groupsAsync = ref.watch(dailyGroupedProvider(range.from, range.to));

    // Watch category providers once at parent level to avoid per-tile rebuilds
    final incomeCategoriesAsync = ref.watch(visibleCategoriesProvider('income'));
    final expenseCategoriesAsync = ref.watch(visibleCategoriesProvider('expense'));
    
    // Build category name map for efficient lookup
    final categoryNameMap = <String, String>{};
    incomeCategoriesAsync.whenData((cats) {
      for (final cat in cats) {
        categoryNameMap[cat.id] = cat.name;
      }
    });
    expenseCategoriesAsync.whenData((cats) {
      for (final cat in cats) {
        categoryNameMap[cat.id] = cat.name;
      }
    });

    final hasRouteFilter = _categoryFilter != null ||
        _customDateFrom != null ||
        _customDateTo != null;

    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(hasRouteFilter, range),
      floatingActionButton: _isSelectionMode
          ? const FloatingActionButton(
              onPressed: null,
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: SizedBox.shrink(),
            )
          : null, // 多选模式下使用透明FAB覆盖AppShell的FAB，非多选模式下使用AppShell的FAB
      body: Stack(
        children: [
          Column(
            children: [
              if (hasRouteFilter)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  child: Text(
                    '已应用筛选条件',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.brandPrimary,
                    ),
                  ),
                ),
              FilterBar(
                selectedDatePreset: _datePreset,
                selectedType: _typeFilter,
                searchQuery: _searchQuery,
                onDatePresetChanged: (preset) =>
                    setState(() => _datePreset = preset),
                onTypeChanged: (type) => setState(() => _typeFilter = type),
                onSearchChanged: (query) => setState(() => _searchQuery = query),
                onAdvancedFilter: () => _showAdvancedFilter(context),
              ),
              if (_swipeDeleteHintShown && !_isSelectionMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  color: AppColors.backgroundTertiary.withValues(alpha: 0.8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.swipe_left,
                        size: AppIconSize.sm,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '左滑可删除',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: AppIconSize.sm),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          setState(() {
                            _swipeDeleteHintShown = false;
                          });
                          SharedPreferences.getInstance().then((prefs) {
                            prefs.setBool(_keySwipeDeleteHintDismissed, true);
                          });
                        },
                        tooltip: '关闭',
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(child: _buildList(groupsAsync, categoryNameMap)),
            ],
          ),
          // FAB toggle button positioned near FAB area (bottom right)
          // Position: right of FAB column, vertically centered with FAB column
          // FAB location: right edge with margin, bottom aligned with action bar top
          if (!_isSelectionMode)
            _buildFabTogglePosition(),
        ],
      ),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar(groupsAsync) : null,
    );
  }

  PreferredSizeWidget _buildNormalAppBar(bool hasRouteFilter, ({DateTime from, DateTime to}) range) {
    return AppBar(
      title: const Text('交易明细'),
      actions: [
        if (hasRouteFilter)
          IconButton(
            icon: const Icon(Icons.filter_alt_off),
            tooltip: '清除筛选',
            onPressed: () => setState(() {
              _categoryFilter = null;
              _customDateFrom = null;
              _customDateTo = null;
              _datePreset = DateRangePreset.thisMonth;
            }),
          ),
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: '导出',
          onPressed: () => _showExportSheet(context, range),
        ),
        IconButton(
          icon: const Icon(Icons.checklist),
          tooltip: '批量操作',
          onPressed: () => setState(() {
            _isSelectionMode = true;
            _selectedIds.clear();
          }),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final count = _selectedIds.length;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        }),
      ),
      title: Text(count > 0 ? '已选择 $count 项' : '选择项目'),
      actions: [
        if (count > 0)
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: '全选/反选',
            onPressed: _toggleSelectAll,
          ),
      ],
    );
  }

  Widget? _buildSelectionBottomBar(AsyncValue<List<DailyTransactionGroup>> groupsAsync) {
    final count = _selectedIds.length;
    
    // 计算总数量以判断是否全选
    final int totalCount = groupsAsync.maybeWhen(
      data: (groups) {
        final filtered = _applyClientFilters(groups);
        var total = 0;
        for (final group in filtered) {
          total += group.transactions.length;
        }
        return total;
      },
      orElse: () => 0,
    );
    
    final allSelected = totalCount > 0 && count == totalCount;
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundPrimary,
        boxShadow: AppShadow.card,
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 左侧：全选复选框
            InkWell(
              onTap: _toggleSelectAll,
              borderRadius: AppRadius.mdAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: allSelected,
                      onChanged: (_) => _toggleSelectAll(),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '全选',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // 右侧：操作按钮组
            TextButton(
              onPressed: _exitSelectionMode,
              child: const Text('取消'),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton.icon(
              onPressed: count > 0 ? _handleBatchDelete : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.expense,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    final range = _datePreset == DateRangePreset.custom
        ? (
            from: _customDateFrom ?? DateTime(2000),
            to: _customDateTo ?? DateTime(2099),
          )
        : resolveDateRange(_datePreset);
    final groupsAsync = ref.read(dailyGroupedProvider(range.from, range.to));
    
    groupsAsync.whenData((groups) {
      final filtered = _applyClientFilters(groups);
      final allIds = <String>{};
      for (final group in filtered) {
        for (final tx in group.transactions.cast<TransactionEntity>()) {
          allIds.add(tx.id);
        }
      }
      
      setState(() {
        if (_selectedIds.length == allIds.length) {
          _selectedIds.clear();
        } else {
          _selectedIds.addAll(allIds);
        }
      });
    });
  }

  Widget _buildList(
    AsyncValue<List<DailyTransactionGroup>> groupsAsync,
    Map<String, String> categoryNameMap,
  ) {
    return groupsAsync.when(
      data: (groups) {
        final filtered = _applyClientFilters(groups);

        if (filtered.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.search_off,
            title: '暂无匹配的交易记录',
          );
        }

        return AnimatedSwitcher(
          duration: AppDuration.normal,
          child: SlidableAutoCloseBehavior(
            child: ListView.builder(
              key: ValueKey(filtered.hashCode),
              itemCount: _countItems(filtered),
              itemBuilder: (context, index) =>
                  _buildItem(context, filtered, index, categoryNameMap),
            ),
          ),
        );
      },
      loading: () => ShimmerPlaceholder.listPlaceholder(itemCount: 8),
      error: (e, _) => ErrorStateWidget(
        message: '加载失败: $e',
        onRetry: () {
          final range = resolveDateRange(_datePreset);
          ref.invalidate(dailyGroupedProvider(range.from, range.to));
        },
      ),
    );
  }

  List<DailyTransactionGroup> _applyClientFilters(
    List<DailyTransactionGroup> groups,
  ) {
    if (_typeFilter == null &&
        _searchQuery.isEmpty &&
        _categoryFilter == null) {
      return groups;
    }

    return groups
        .map((g) {
          final txList = g.transactions.cast<TransactionEntity>().where((tx) {
            if (_typeFilter != null && tx.type.name != _typeFilter) {
              return false;
            }
            if (_categoryFilter != null &&
                tx.categoryId != _categoryFilter) {
              return false;
            }
            if (_searchQuery.isNotEmpty) {
              final desc = tx.description;
              if (desc == null ||
                  !desc.toLowerCase().contains(_searchQuery.toLowerCase())) {
                return false;
              }
            }
            return true;
          }).toList();

          if (txList.isEmpty) return null;

          return DailyTransactionGroup(
            date: g.date,
            dailyIncome: g.dailyIncome,
            dailyExpense: g.dailyExpense,
            transactions: txList,
          );
        })
        .whereType<DailyTransactionGroup>()
        .toList();
  }

  int _countItems(List<DailyTransactionGroup> groups) {
    var count = 0;
    for (final g in groups) {
      count += 1 + g.transactions.length;
    }
    return count;
  }

  Widget _buildItem(
    BuildContext context,
    List<DailyTransactionGroup> groups,
    int index,
    Map<String, String> categoryNameMap,
  ) {
    var offset = 0;
    for (final group in groups) {
      if (index == offset) {
        return DailyGroupHeader(
          date: group.date,
          dailyIncome: group.dailyIncome,
          dailyExpense: group.dailyExpense,
        );
      }
      offset++;
      if (index < offset + group.transactions.length) {
        final tx = group.transactions[index - offset] as TransactionEntity;
        final categoryName = tx.categoryId != null
            ? categoryNameMap[tx.categoryId]
            : null;
        return _TransactionTileWithCategory(
          transaction: tx,
          categoryName: categoryName,
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedIds.contains(tx.id),
          onEdit: () => context.push('/record/${tx.id}'),
          onDelete: () => _deleteTransaction(tx.id),
          onSelectionChanged: (selected) {
            setState(() {
              if (selected) {
                _selectedIds.add(tx.id);
              } else {
                _selectedIds.remove(tx.id);
              }
            });
          },
          onLongPress: () {
            if (!_isSelectionMode) {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.add(tx.id);
              });
            }
          },
        );
      }
      offset += group.transactions.length;
    }
    return const SizedBox.shrink();
  }

  Future<void> _deleteTransaction(String id) async {
    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.delete(id);
      invalidateTransactionQueries(ref);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 $count 条交易记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.expense,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final idsToDelete = _selectedIds.toList();
      await repo.deleteBatch(idsToDelete);
      invalidateTransactionQueries(ref);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已删除 $count 条记录'),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败：$e')),
      );
    }
  }

  void _showAdvancedFilter(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('高级筛选', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            const Text('更多筛选选项（分类、金额范围等）将在后续版本完善'),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the FAB toggle button positioned near the FAB area.
  /// Extracts MediaQuery calculation to avoid repeated calculations in build method.
  Widget _buildFabTogglePosition() {
    final mediaQuery = MediaQuery.of(context);
    return Positioned(
      right: mediaQuery.padding.right +
          16 + // kFloatingActionButtonMargin
          56 + // FAB width
          AppSpacing.md, // Spacing between FAB and toggle button
      bottom: mediaQuery.padding.bottom +
          80 + // Bottom navigation bar height
          100 + // Action bar height
          56 + // Plus FAB height
          AppSpacing.sm + // Spacing between FABs
          28, // Half of toggle button height (40/2) to center it with FAB column
      child: const RepaintBoundary(
        child: FabToggleButton(),
      ),
    );
  }
}

/// Transaction tile with category name resolved at parent level.
/// No longer watches category provider to avoid per-tile rebuilds.
class _TransactionTileWithCategory extends StatelessWidget {
  const _TransactionTileWithCategory({
    required this.transaction,
    this.categoryName,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onEdit,
    required this.onDelete,
    this.onSelectionChanged,
    this.onLongPress,
  });

  final TransactionEntity transaction;
  final String? categoryName;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return TransactionTile(
      transaction: transaction,
      categoryName: categoryName,
      isSelectionMode: isSelectionMode,
      isSelected: isSelected,
      onEdit: onEdit,
      onDelete: onDelete,
      onSelectionChanged: onSelectionChanged,
      onLongPress: onLongPress,
    );
  }
}
