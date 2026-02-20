import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
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

    final hasRouteFilter = _categoryFilter != null ||
        _customDateFrom != null ||
        _customDateTo != null;

    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(hasRouteFilter, range),
      body: Column(
        children: [
          if (hasRouteFilter)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              child: Text(
                '已应用筛选条件',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
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
          const Divider(height: 1),
          Expanded(child: _buildList(groupsAsync)),
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
    int totalCount = groupsAsync.maybeWhen(
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
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 全选复选框
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // 已选择数量
            Text(
              '已选择 $count 项',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            // 删除按钮，添加右侧padding避免FAB遮挡
            Padding(
              padding: const EdgeInsets.only(right: 88), // FAB宽度56 + 间距32
              child: FilledButton.icon(
                onPressed: count > 0 ? _handleBatchDelete : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildList(AsyncValue<List<DailyTransactionGroup>> groupsAsync) {
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
          child: ListView.builder(
            key: ValueKey(filtered.hashCode),
            itemCount: _countItems(filtered),
            itemBuilder: (context, index) =>
                _buildItem(context, filtered, index),
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
        return _TransactionTileWithCategory(
          transaction: tx,
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
              foregroundColor: Theme.of(ctx).colorScheme.error,
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
}

/// Resolves category name for a transaction tile.
class _TransactionTileWithCategory extends ConsumerWidget {
  const _TransactionTileWithCategory({
    required this.transaction,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onEdit,
    required this.onDelete,
    this.onSelectionChanged,
    this.onLongPress,
  });

  final TransactionEntity transaction;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String? catName;
    if (transaction.categoryId != null) {
      final type = transaction.type == TransactionType.income
          ? 'income'
          : 'expense';
      final catsAsync = ref.watch(visibleCategoriesProvider(type));
      catName = catsAsync.whenOrNull(
        data: (cats) {
          final match = cats.where((c) => c.id == transaction.categoryId);
          return match.isNotEmpty ? match.first.name : null;
        },
      );
    }

    return TransactionTile(
      transaction: transaction,
      categoryName: catName,
      isSelectionMode: isSelectionMode,
      isSelected: isSelected,
      onEdit: onEdit,
      onDelete: onDelete,
      onSelectionChanged: onSelectionChanged,
      onLongPress: onLongPress,
    );
  }
}
