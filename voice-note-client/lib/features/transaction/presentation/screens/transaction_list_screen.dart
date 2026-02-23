import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../export/presentation/widgets/export_options_sheet.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../../category/domain/entities/category_entity.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../providers/transaction_form_providers.dart';
import '../providers/transaction_query_providers.dart';
import '../../../home/presentation/widgets/recent_transaction_tile.dart';
import '../widgets/transaction_calendar_grid.dart';
import '../widgets/transaction_calendar_header.dart';

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
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = <String>{};
  bool _deleteHintShown = false;

  static const _keyDeleteHintShown = 'transaction_list_delete_hint_shown';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now;
    _checkAndShowDeleteHint();
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

  void _showExportSheet(BuildContext context, DateTime currentMonth) {
    final start = DateTime(currentMonth.year, currentMonth.month, 1);
    final end = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExportOptionsSheet(
        initialDateFrom: start,
        initialDateTo: end,
        initialType: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarGroupsAsync = ref.watch(calendarMonthGroupsProvider(_currentMonth));
    final listAsync = ref.watch(selectedDateTransactionsProvider(_selectedDate));

    final incomeCategoriesAsync = ref.watch(visibleCategoriesProvider('income'));
    final expenseCategoriesAsync = ref.watch(visibleCategoriesProvider('expense'));
    final categoryNameMap = <String, String>{};
    final categoryIconMap = <String, String>{};
    final categoryColorMap = <String, Color>{};
    void fillMaps(List<CategoryEntity> cats) {
      for (final cat in cats) {
        categoryNameMap[cat.id] = cat.name;
        categoryIconMap[cat.id] = cat.icon;
        categoryColorMap[cat.id] = _parseCategoryColor(cat.color);
      }
    }
    incomeCategoriesAsync.whenData(fillMaps);
    expenseCategoriesAsync.whenData(fillMaps);

    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(_currentMonth),
      floatingActionButton: null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          calendarGroupsAsync.when(
            data: (groups) => TransactionCalendarGrid(
              monthHeader: TransactionCalendarHeader(
                currentMonth: _currentMonth,
                onPrevMonth: () {
                  setState(() {
                    if (_currentMonth.month == 1) {
                      _currentMonth = DateTime(_currentMonth.year - 1, 12, 1);
                    } else {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
                    }
                  });
                },
                onNextMonth: () {
                  setState(() {
                    if (_currentMonth.month == 12) {
                      _currentMonth = DateTime(_currentMonth.year + 1, 1, 1);
                    } else {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
                    }
                  });
                },
                onBackToToday: () {
                  setState(() {
                    final now = DateTime.now();
                    _currentMonth = DateTime(now.year, now.month, 1);
                    _selectedDate = now;
                  });
                },
              ),
              currentMonth: _currentMonth,
              selectedDate: _selectedDate,
              dailyGroups: groups,
              onSelectDate: (DateTime d) => setState(() => _selectedDate = d),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => const SizedBox.shrink(),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedDateLabel(_selectedDate),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                listAsync.when(
                  data: (list) {
                    final (expense, income) = _dailyTotalsFromList(list);
                    final expenseStr = NumberFormat.currency(
                      locale: 'zh_CN',
                      symbol: '¥',
                      decimalDigits: 2,
                    ).format(expense);
                    final incomeStr = NumberFormat.currency(
                      locale: 'zh_CN',
                      symbol: '¥',
                      decimalDigits: 2,
                    ).format(income);
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '支出$expenseStr · 收入$incomeStr',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _buildSelectedDayList(
                listAsync,
                categoryNameMap,
                categoryIconMap,
                categoryColorMap,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isSelectionMode ? _buildSelectionBottomBar(listAsync) : null,
    );
  }

  String _selectedDateLabel(DateTime d) {
    final today = DateTime.now();
    final sameDay = d.year == today.year && d.month == today.month && d.day == today.day;
    final prefix = sameDay ? '今天' : '';
    final suffix = '${d.month}月${d.day}日（周${['一', '二', '三', '四', '五', '六', '日'][d.weekday - 1]}）';
    return prefix.isEmpty ? suffix : '$prefix $suffix';
  }

  /// 当日支出/收入合计（含转入计收入、转出计支出），与首页 DailyGroupHeader 口径一致。
  /// 转账且 transferDirection 为 null 时不纳入当日收支。
  static (double expense, double income) _dailyTotalsFromList(
    List<TransactionEntity> list,
  ) {
    double expense = 0;
    double income = 0;
    for (final tx in list) {
      switch (tx.type) {
        case TransactionType.expense:
          expense += tx.amount;
          break;
        case TransactionType.income:
          income += tx.amount;
          break;
        case TransactionType.transfer:
          if (tx.transferDirection == TransferDirection.outbound) {
            expense += tx.amount;
          } else if (tx.transferDirection == TransferDirection.inbound) {
            income += tx.amount;
          }
          break;
      }
    }
    return (expense, income);
  }

  /// 从统计等页带筛选进入时显示返回键。Shell 下同级路由无栈可 pop，用 go 回统计。
  bool get _canPop => widget.filterCategoryId != null ||
      widget.filterDateFrom != null ||
      widget.filterDateTo != null;

  void _onBackFromFiltered() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.statistics);
    }
  }

  PreferredSizeWidget _buildNormalAppBar(DateTime currentMonth) {
    return AppBar(
      leading: _canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _onBackFromFiltered,
              tooltip: '返回',
            )
          : null,
      title: const Text('全部列表'),
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: '导出',
          onPressed: () => _showExportSheet(context, currentMonth),
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

  Widget? _buildSelectionBottomBar(AsyncValue<List<TransactionEntity>> listAsync) {
    final count = _selectedIds.length;
    final int totalCount = listAsync.maybeWhen(
      data: (list) => list.length,
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
    final listAsync = ref.read(selectedDateTransactionsProvider(_selectedDate));
    listAsync.whenData((list) {
      setState(() {
        if (_selectedIds.length == list.length) {
          _selectedIds.clear();
        } else {
          _selectedIds.addAll(list.map((e) => e.id));
        }
      });
    });
  }

  Widget _buildSelectedDayList(
    AsyncValue<List<TransactionEntity>> listAsync,
    Map<String, String> categoryNameMap,
    Map<String, String> categoryIconMap,
    Map<String, Color> categoryColorMap,
  ) {
    return listAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.receipt_long_outlined,
            title: '当天暂无记录',
          );
        }
        return AnimatedSwitcher(
          duration: AppDuration.normal,
          child: SlidableAutoCloseBehavior(
            child: ListView.builder(
              key: ValueKey('${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}-${list.length}'),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final tx = list[index];
                final categoryName = tx.categoryId != null ? categoryNameMap[tx.categoryId] : null;
                final categoryIconStr = tx.categoryId != null ? categoryIconMap[tx.categoryId] : null;
                final categoryColor = tx.categoryId != null ? categoryColorMap[tx.categoryId] : null;
                return _TransactionTileWithCategory(
                  transaction: tx,
                  categoryName: categoryName,
                  categoryIconStr: categoryIconStr,
                  categoryColor: categoryColor,
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
              },
            ),
          ),
        );
      },
      loading: () => ShimmerPlaceholder.listPlaceholder(itemCount: 8),
      error: (e, _) => ErrorStateWidget(
        message: '加载失败: $e',
        onRetry: () {
          ref.invalidate(selectedDateTransactionsProvider(_selectedDate));
        },
      ),
    );
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

  static Color _parseCategoryColor(String hex) {
    final s = hex.replaceFirst(RegExp(r'^#'), '').trim();
    final hexOnly = RegExp(r'^[0-9A-Fa-f]{6}$');
    final hexWithAlpha = RegExp(r'^[0-9A-Fa-f]{8}$');
    if (s.isEmpty || (!hexOnly.hasMatch(s) && !hexWithAlpha.hasMatch(s))) {
      return AppColors.textSecondary;
    }
    final full = s.length == 6 ? 'FF$s' : s;
    return Color(int.parse(full, radix: 16));
  }
}

/// List item aligned with home: RecentTransactionTile (category chip, time·category, 收入/支出颜色一致).
class _TransactionTileWithCategory extends StatelessWidget {
  const _TransactionTileWithCategory({
    required this.transaction,
    this.categoryName,
    this.categoryIconStr,
    this.categoryColor,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onEdit,
    required this.onDelete,
    this.onSelectionChanged,
    this.onLongPress,
  });

  final TransactionEntity transaction;
  final String? categoryName;
  final String? categoryIconStr;
  final Color? categoryColor;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return RecentTransactionTile(
      transaction: transaction,
      categoryName: categoryName,
      categoryColor: categoryColor,
      categoryIconStr: categoryIconStr,
      isSelectionMode: isSelectionMode,
      isSelected: isSelected,
      onTap: onEdit,
      onDelete: onDelete,
      onSelectionChanged: onSelectionChanged,
      onLongPress: onLongPress,
    );
  }
}
