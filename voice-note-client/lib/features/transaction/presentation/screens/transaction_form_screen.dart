import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/id_generator.dart' as id_gen;
import '../../../../shared/error_copy.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../../shared/widgets/time_picker_dialog.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../../account/presentation/providers/account_providers.dart';
import '../../../budget/domain/budget_service.dart';
import '../../../budget/presentation/providers/budget_providers.dart';
import '../../../account/domain/entities/account_entity.dart';
import '../../../category/domain/entities/category_entity.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../providers/transaction_form_providers.dart';
import '../providers/transaction_query_providers.dart';
import '../widgets/category_chip.dart';
import '../widgets/category_grid.dart';
import '../widgets/date_quick_select.dart';
import '../widgets/number_pad.dart';
import '../widgets/transfer_fields.dart';
import '../widgets/type_selector.dart';

/// Screen for creating or editing a transaction.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({super.key, this.transactionId});

  final String? transactionId;

  bool get isEditing => transactionId != null;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

/// Scroll offset above which the number pad is hidden when user scrolls down.
const double _scrollThresholdToHideNumberPad = 80;

/// Enterprise-style form: compact rows, consistent radius, subtle elevation.
class _FormLayout {
  static const double cardRadius = 12.0;
  static const double remarkHeight = 112.0;
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: 6,
  );
  static const EdgeInsets sectionPadding = EdgeInsets.all(AppSpacing.md);
  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textPlaceholder,
    letterSpacing: 0.6,
  );
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _amountController = AmountInputController();
  final _descriptionController = TextEditingController();
  final _descriptionFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _initialized = false;
  bool _counterpartyFocused = false;
  bool _showNumberPad = false;
  /// Snapshot of form state when entering record detail; save enabled only when form differs.
  TransactionFormState? _initialEditState;

  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_scrollController.offset > _scrollThresholdToHideNumberPad &&
        _showNumberPad) {
      FocusScope.of(context).unfocus();
      setState(() => _showNumberPad = false);
    }
  }

  /// Only hide pad when a text field gains focus; do not show pad when focus is lost (user must tap amount to show).
  void _updateShowNumberPad() {
    if (!mounted) return;
    final anyTextFieldFocused =
        _descriptionFocusNode.hasFocus || _counterpartyFocused;
    if (anyTextFieldFocused && _showNumberPad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showNumberPad = false);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _descriptionFocusNode.removeListener(_updateShowNumberPad);
    _descriptionFocusNode.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initEditMode() async {
    if (_initialized || !widget.isEditing) return;
    _initialized = true;

    final repo = ref.read(transactionRepositoryProvider);
    final entity = await repo.getById(widget.transactionId!);
    if (entity == null || !mounted) return;

    ref.read(transactionFormProvider.notifier).loadFromEntity(entity);
    _amountController.setFromDouble(entity.amount);
    _descriptionController.text = entity.description ?? '';
    _initialEditState = ref.read(transactionFormProvider);
    setState(() {});
  }

  void _onAmountAreaTap() {
    FocusScope.of(context).unfocus();
    if (!_showNumberPad) setState(() => _showNumberPad = true);
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _descriptionFocusNode.addListener(_updateShowNumberPad);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isEditing) {
        _initEditMode();
      } else {
        ref.read(transactionFormProvider.notifier).reset();
        _amountController.clear();
        _descriptionController.clear();
        // Default account to wallet so dropdown shows 钱包
        ref.read(defaultAccountProvider.future).then((acc) {
          if (acc != null && mounted) {
            ref.read(transactionFormProvider.notifier).setAccountId(acc.id);
          }
        });
      }
    });
  }

  void _onCounterpartyFocusChange(bool hasFocus) {
    if (_counterpartyFocused == hasFocus) return;
    setState(() {
      _counterpartyFocused = hasFocus;
      if (hasFocus) _showNumberPad = false;
    });
  }

  /// True if any field differs from the snapshot taken when entering record detail.
  bool _hasEditFormChanged(TransactionFormState formState) {
    final init = _initialEditState;
    if (init == null) return false;
    final currentAmount = _amountController.toDouble();
    return formState.selectedType != init.selectedType ||
        currentAmount != init.amount ||
        formState.categoryId != init.categoryId ||
        !formState.date.isAtSameMomentAs(init.date) ||
        (formState.description ?? '') != (init.description ?? '') ||
        formState.accountId != init.accountId ||
        formState.transferDirection != init.transferDirection ||
        (formState.counterparty ?? '') != (init.counterparty ?? '');
  }

  /// Hide number pad when user interacts with non-amount areas (type, date, category, transfer direction).
  void _hideNumberPad() {
    FocusScope.of(context).unfocus();
    if (_showNumberPad) setState(() => _showNumberPad = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(transactionFormProvider);
    final isTransfer = formState.selectedType == TransactionType.transfer;
    final categoryType = formState.selectedType == TransactionType.income
        ? 'income'
        : formState.selectedType == TransactionType.transfer
        ? (formState.transferDirection == TransferDirection.inbound
              ? 'income'
              : 'expense')
        : 'expense';

    final transferDir =
        formState.transferDirection ?? TransferDirection.outbound;
    ref.listen(transferDefaultCategoryIdProvider(transferDir), (prev, next) {
      next.whenData((id) {
        if (id != null &&
            ref.read(transactionFormProvider).categoryId == null) {
          ref.read(transactionFormProvider.notifier).setCategoryId(id);
        }
      });
    });

    final formValid =
        _amountController.toDouble() > 0 && formState.categoryId != null;
    final canSave = formValid &&
        (!widget.isEditing ||
            _initialEditState == null ||
            _hasEditFormChanged(formState));

    // Hide save bar while editing (description/counterparty) or while amount number pad is shown; "完成" only dismisses input, then user reviews and taps save.
    final isEditingText =
        _descriptionFocusNode.hasFocus || _counterpartyFocused;
    final showSaveBar = !isEditingText && !_showNumberPad;
    final showAmountDoneBar = _showNumberPad;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          widget.isEditing ? '记录详情' : '记一笔',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
        actions: [
          if (widget.isEditing && widget.transactionId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 22),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          const dividerHeight = 1.0;
          const saveBarHeight = 60.0;
          final reserveForBottomBar = (showSaveBar || showAmountDoneBar)
              ? saveBarHeight
              : 0.0;
          final numberPadMaxH = _showNumberPad
              ? (availableHeight - dividerHeight - reserveForBottomBar).clamp(
                  0.0,
                  MediaQuery.sizeOf(context).height * 0.28,
                )
              : 0.0;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xs,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDetailCard(
                        context,
                        formState,
                        isTransfer,
                        isRecordDetail: widget.isEditing,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _buildRemarksSection(context),
                      if (!widget.isEditing) ...[
                        const SizedBox(height: AppSpacing.sm),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DateQuickSelect(
                            selected: formState.date,
                            onChanged: (date) {
                              _hideNumberPad();
                              ref
                                  .read(transactionFormProvider.notifier)
                                  .setDate(date);
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildSection(
                          context,
                          title: isTransfer ? '转账' : '选择分类',
                          child: isTransfer
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    TransferFields(
                                      direction: formState.transferDirection,
                                      counterparty: formState.counterparty,
                                      onDirectionChanged: (dir) {
                                        _hideNumberPad();
                                        ref
                                            .read(
                                              transactionFormProvider.notifier,
                                            )
                                            .setTransferDirection(dir);
                                      },
                                      onCounterpartyChanged: (val) {
                                        ref
                                            .read(
                                              transactionFormProvider.notifier,
                                            )
                                            .setCounterparty(val);
                                      },
                                      onCounterpartyFocusChange:
                                          _onCounterpartyFocusChange,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _buildCategorySection(
                                      categoryType,
                                      formState,
                                      onCategoryTap: _hideNumberPad,
                                    ),
                                  ],
                                )
                              : _buildCategorySection(
                                  categoryType,
                                  formState,
                                  onCategoryTap: _hideNumberPad,
                                ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildAccountSectionWithTitle(context, formState),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.06),
              ),
              if (_showNumberPad && numberPadMaxH > 0)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: numberPadMaxH),
                  child: NumberPad(
                    onKey: (key) {
                      _amountController.append(key);
                      ref
                          .read(transactionFormProvider.notifier)
                          .setAmount(_amountController.toDouble());
                      setState(() {});
                    },
                    onBackspace: () {
                      _amountController.backspace();
                      ref
                          .read(transactionFormProvider.notifier)
                          .setAmount(_amountController.toDouble());
                      setState(() {});
                    },
                  ),
                ),
              if (showAmountDoneBar) _buildAmountDoneBar(),
              if (showSaveBar) _buildBottomSaveBar(canSave, formState),
            ],
          );
        },
      ),
    );
  }

  /// "完成" bar when number pad is visible: dismisses pad so user can review page then tap save.
  Widget _buildAmountDoneBar() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          button: true,
          label: '完成',
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _hideNumberPad,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_FormLayout.cardRadius),
                ),
              ),
              child: const Text('完成'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: _FormLayout.sectionPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_FormLayout.cardRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(title, style: _FormLayout.sectionTitleStyle),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String categoryType,
    TransactionFormState formState, {
    VoidCallback? onCategoryTap,
    VoidCallback? onAfterSelect,
  }) {
    final categoriesAsync = ref.watch(visibleCategoriesProvider(categoryType));
    final recentIdsAsync = ref.watch(recentCategoriesProvider);
    final recommendedNames = ref.watch(recommendedCategoryNamesProvider);

    void onSelected(String id) {
      onCategoryTap?.call();
      ref.read(transactionFormProvider.notifier).setCategoryId(id);
      onAfterSelect?.call();
    }

    return categoriesAsync.when(
      data: (categories) {
        final recentIds = recentIdsAsync.when(
          data: (ids) => ids,
          loading: () => <String>[],
          error: (e, st) => <String>[],
        );
        final recentCategories = categories
            .where((c) => recentIds.contains(c.id))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RecentCategoryChips(
              categories: recentCategories,
              selectedId: formState.categoryId,
              onSelected: onSelected,
            ),
            if (recentCategories.isNotEmpty)
              const SizedBox(height: AppSpacing.sm),
            CategoryGrid(
              categories: categories,
              selectedId: formState.categoryId,
              onSelected: onSelected,
              recommendedNames: recommendedNames,
            ),
          ],
        );
      },
      loading: () => ShimmerPlaceholder.listPlaceholder(itemCount: 2),
      error: (e, _) {
            debugPrint('加载分类失败: $e');
            return ErrorStateWidget(
              message: ErrorCopy.loadFailed,
              onRetry: () => ref.invalidate(visibleCategoriesProvider(categoryType)),
            );
          },
    );
  }

  /// 账户区块：当前保留，多账户设计尚未引入；引入后支持将本笔交易关联到所选账户。
  Widget _buildAccountSectionWithTitle(
    BuildContext context,
    TransactionFormState formState,
  ) {
    final multiAccountAsync = ref.watch(multiAccountEnabledProvider);

    return multiAccountAsync.when(
      data: (enabled) {
        // 多账户开启时账户行在详情卡片内展示，此处不重复
        if (enabled) return const SizedBox.shrink();

        final accountsAsync = ref.watch(accountListProvider);
        return accountsAsync.when(
          data: (accounts) {
            if (accounts.isEmpty) {
              return _buildSection(
                context,
                title: '账户',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    '暂无账户',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            final ids = accounts.map((a) => a.id).toSet();
            final currentId = formState.accountId;
            final value =
                (currentId != null &&
                    currentId.isNotEmpty &&
                    ids.contains(currentId))
                ? currentId
                : accounts.first.id;
            final theme = Theme.of(context);
            final safeTitleMedium = theme.textTheme.titleMedium?.copyWith(
                  fontSize: theme.textTheme.titleMedium?.fontSize ?? 14,
                  height: theme.textTheme.titleMedium?.height ?? 1.0,
                ) ??
                const TextStyle(fontSize: 14, height: 1.0);
            return _buildSection(
              context,
              title: '账户',
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Theme(
                  data: theme.copyWith(
                    textTheme: theme.textTheme.copyWith(titleMedium: safeTitleMedium),
                  ),
                  child: DropdownButtonFormField<String>(
                  key: ValueKey(value),
                  value: value,
                  decoration: const InputDecoration(
                    labelText: '选择账户',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  items: accounts
                      .map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      )
                      .toList(),
                  onChanged: (id) {
                    ref.read(transactionFormProvider.notifier).setAccountId(id);
                  },
                ),
                ),
              ),
            );
          },
          loading: () => ShimmerPlaceholder.listItem(),
          error: (e, _) {
            debugPrint('加载账户失败: $e');
            return ErrorStateWidget(
              message: ErrorCopy.loadFailed,
              onRetry: () => ref.invalidate(accountListProvider),
            );
          },
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || widget.transactionId == null) return;
    try {
      await ref
          .read(transactionRepositoryProvider)
          .delete(widget.transactionId!);
      invalidateTransactionQueries(ref);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除')));
    } catch (e) {
      if (!mounted) return;
      debugPrint('删除失败: $e');
      _showError(ErrorCopy.deleteFailed);
    }
  }

  Future<void> _save(TransactionFormState formState) async {
    // Validate amount
    if (_amountController.toDouble() <= 0) {
      _showError(ErrorCopy.amountRequired);
      return;
    }

    if (formState.categoryId == null) {
      _showError(ErrorCopy.categoryRequired);
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);

    // Resolve account ID
    String accountId = formState.accountId ?? '';
    if (accountId.isEmpty) {
      final defaultAccount = await ref.read(defaultAccountProvider.future);
      accountId = defaultAccount?.id ?? '';
    }

    // Default transfer direction to outbound if not set
    final transferDir = formState.selectedType == TransactionType.transfer
        ? (formState.transferDirection ?? TransferDirection.outbound)
        : formState.transferDirection;

    final now = DateTime.now();

    try {
      if (widget.isEditing) {
        final existing = await repo.getById(widget.transactionId!);
        if (existing == null) return;

        final updated = existing.copyWith(
          type: formState.selectedType,
          amount: _amountController.toDouble(),
          categoryId: () => formState.categoryId,
          date: formState.date,
          description: () => formState.description,
          accountId: accountId,
          transferDirection: () => transferDir,
          counterparty: () => formState.counterparty,
          updatedAt: now,
        );
        await repo.update(updated);
      } else {
        final entity = TransactionEntity(
          id: id_gen.generateId(),
          type: formState.selectedType,
          amount: _amountController.toDouble(),
          date: formState.date,
          description: formState.description,
          categoryId: formState.categoryId,
          accountId: accountId,
          transferDirection: transferDir,
          counterparty: formState.counterparty,
          createdAt: now,
          updatedAt: now,
        );
        await repo.create(entity);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('保存失败: $e');
      _showError(ErrorCopy.saveFailed);
      return;
    }

    // Refresh all transaction query providers so lists update immediately
    invalidateTransactionQueries(ref);

    // Async budget check for expense transactions
    if (formState.selectedType == TransactionType.expense &&
        formState.categoryId != null) {
      final budgetSvc = ref.read(budgetServiceProvider);
      final yearMonth = BudgetService.currentYearMonth();
      budgetSvc.checkAfterSave(
        categoryId: formState.categoryId!,
        yearMonth: yearMonth,
      );
    }

    if (!mounted) return;
    context.pop();
  }

  Widget _buildBottomSaveBar(bool canSave, TransactionFormState formState) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Semantics(
          button: true,
          enabled: canSave,
          label: '保存',
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canSave ? () => _save(formState) : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_FormLayout.cardRadius),
                ),
              ),
              child: const Text('保存'),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.softErrorText,
          ),
        ),
        backgroundColor: AppColors.softErrorBackground,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Widget _dashedDivider(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.18),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget right,
    bool showArrow = true,

    /// 为 true 时 right 用 Expanded 占满剩余宽度，避免溢出（如类型行的分段按钮）。
    bool expandRight = false,
  }) {
    final theme = Theme.of(context);
    final rightChild = expandRight ? Expanded(child: right) : right;
    return Padding(
      padding: _FormLayout.cardPadding,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (!expandRight) const Spacer(),
          rightChild,
          if (showArrow) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textPlaceholder,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailCard(
    BuildContext context,
    TransactionFormState formState,
    bool isTransfer, {
    required bool isRecordDetail,
  }) {
    final theme = Theme.of(context);
    final multiAccountAsync = ref.watch(multiAccountEnabledProvider);
    final accountsAsync = ref.watch(accountListProvider);
    final amount = _amountController.toDouble();
    final amountStr = amount <= 0
        ? '0'
        : (formState.selectedType == TransactionType.expense
              ? '-¥${amount.toStringAsFixed(2)}'
              : formState.selectedType == TransactionType.income
              ? '+¥${amount.toStringAsFixed(2)}'
              : '¥${amount.toStringAsFixed(2)}');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(_FormLayout.cardRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: AppShadow.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _onAmountAreaTap,
            behavior: HitTestBehavior.opaque,
            child: _buildDetailRow(
              context,
              icon: Icons.currency_yuan_rounded,
              label: '金额',
              right: Text(
                amountStr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          _dashedDivider(context),
          _buildDetailRow(
            context,
            icon: Icons.swap_horiz_rounded,
            label: '类型',
            expandRight: true,
            right: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: TypeSelector(
                selected: formState.selectedType,
                onChanged: (type) {
                  _hideNumberPad();
                  ref.read(transactionFormProvider.notifier).setType(type);
                },
                showTransfer: false,
              ),
            ),
            showArrow: false,
          ),
          if (isRecordDetail) ...[
            _dashedDivider(context),
            _buildCategoryDetailRow(context, formState),
          ],
          ...multiAccountAsync.when(
            data: (multiEnabled) {
              if (!multiEnabled) return <Widget>[];
              return [
                _dashedDivider(context),
                _buildAccountRow(context, formState, accountsAsync),
              ];
            },
            loading: () => [],
            error: (_, _) => [],
          ),
          if (isRecordDetail) ...[
            _dashedDivider(context),
            GestureDetector(
              onTap: () => _showDateTimePicker(context, formState),
              behavior: HitTestBehavior.opaque,
              child: _buildDetailRow(
                context,
                icon: Icons.calendar_today_rounded,
                label: '日期',
                right: Text(
                  DateFormat('yyyy.MM.dd HH:mm').format(formState.date),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 备注区块：紧凑白底卡片 + 多行文本域，右下角 0/30。
  Widget _buildRemarksSection(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: AppSpacing.xs, bottom: 2),
          child: Text('备注', style: _FormLayout.sectionTitleStyle),
        ),
        SizedBox(
          height: _FormLayout.remarkHeight,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(_FormLayout.cardRadius),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: AppShadow.card,
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _descriptionController,
              builder: (context, value, child) {
                return Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    TextField(
                      controller: _descriptionController,
                      focusNode: _descriptionFocusNode,
                      textInputAction: TextInputAction.done,
                      minLines: 4,
                      maxLines: 4,
                      maxLength: 30,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '选填',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPlaceholder,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.only(
                          top: 2,
                          right: 36,
                          bottom: 2,
                          left: 0,
                        ),
                        counterText: '',
                      ),
                      onChanged: (val) {
                        ref
                            .read(transactionFormProvider.notifier)
                            .setDescription(val.isEmpty ? null : val);
                      },
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 2, bottom: 2),
                      child: Text(
                        '${value.text.length}/30',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPlaceholder,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDetailRow(
    BuildContext context,
    TransactionFormState formState,
  ) {
    final categoryType = formState.selectedType == TransactionType.income
        ? 'income'
        : (formState.selectedType == TransactionType.transfer &&
                formState.transferDirection == TransferDirection.inbound)
            ? 'income'
            : 'expense';
    final categoriesAsync = ref.watch(visibleCategoriesProvider(categoryType));
    final theme = Theme.of(context);

    return categoriesAsync.when(
      data: (categories) {
        CategoryEntity? selected;
        if (formState.categoryId != null) {
          try {
            selected = categories
                .firstWhere((c) => c.id == formState.categoryId);
          } catch (_) {}
        }
        return GestureDetector(
          onTap: () => _showCategoryPicker(context, categoryType, formState),
          behavior: HitTestBehavior.opaque,
          child: _buildDetailRow(
            context,
            icon: Icons.category_rounded,
            label: '分类',
            right: Text(
              selected?.name ?? '选择分类',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected != null
                    ? theme.colorScheme.onSurface
                    : AppColors.textPlaceholder,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
      loading: () => _buildDetailRow(
        context,
        icon: Icons.category_rounded,
        label: '分类',
        right: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        showArrow: true,
      ),
      error: (_, _) => _buildDetailRow(
        context,
        icon: Icons.category_rounded,
        label: '分类',
        right: const Text('选择分类'),
        showArrow: true,
      ),
    );
  }

  Widget _buildAccountRow(
    BuildContext context,
    TransactionFormState formState,
    AsyncValue<List<AccountEntity>> accountsAsync,
  ) {
    final theme = Theme.of(context);
    return accountsAsync.when(
      data: (accounts) {
        final id = formState.accountId;
        String? name;
        if (id != null) {
          try {
            name = accounts.firstWhere((a) => a.id == id).name;
          } catch (_) {}
        }
        return GestureDetector(
          onTap: () => _showAccountPicker(context, accounts),
          behavior: HitTestBehavior.opaque,
          child: _buildDetailRow(
            context,
            icon: Icons.account_balance_wallet_rounded,
            label: '账户',
            right: Text(
              name ?? '选择',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: name != null
                    ? theme.colorScheme.onSurface
                    : AppColors.textPlaceholder,
                fontWeight: name != null ? FontWeight.w500 : null,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
      loading: () => _buildDetailRow(
        context,
        icon: Icons.account_balance_wallet_rounded,
        label: '账户',
        right: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        showArrow: true,
      ),
      error: (_, _) => _buildDetailRow(
        context,
        icon: Icons.account_balance_wallet_rounded,
        label: '账户',
        right: const Text('选择'),
        showArrow: true,
      ),
    );
  }

  Future<void> _showDateTimePicker(
    BuildContext context,
    TransactionFormState formState,
  ) async {
    _hideNumberPad();
    final date = await showDatePicker(
      context: context,
      initialDate: formState.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final initialTime = DateTime(
      date.year,
      date.month,
      date.day,
      formState.date.hour,
      formState.date.minute,
      0,
    );
    final timeResult = await showTimePickerDialog(context, initial: initialTime);
    if (!mounted) return;
    final newDateTime = timeResult ??
        DateTime(
          date.year,
          date.month,
          date.day,
          formState.date.hour,
          formState.date.minute,
          0,
        );
    ref.read(transactionFormProvider.notifier).setDate(newDateTime);
  }

  Future<void> _showAccountPicker(
    BuildContext context,
    List<AccountEntity> accounts,
  ) async {
    _hideNumberPad();
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...accounts.map(
              (a) => ListTile(
                title: Text(a.name),
                onTap: () => Navigator.of(ctx).pop(a.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (id != null && mounted) {
      ref.read(transactionFormProvider.notifier).setAccountId(id);
    }
  }

  Future<void> _showCategoryPicker(
    BuildContext context,
    String categoryType,
    TransactionFormState formState,
  ) async {
    _hideNumberPad();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '选择分类',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.08),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: _buildCategorySection(
                  categoryType,
                  formState,
                  onCategoryTap: _hideNumberPad,
                  onAfterSelect: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a horizontal dashed line.
class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 4.0;
    const gap = 4.0;
    final paint = Paint()..color = color;
    double x = 0;
    while (x < size.width) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, dashWidth.clamp(0, size.width - x), 1),
        paint,
      );
      x += dashWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
