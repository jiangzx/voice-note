import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/utils/id_generator.dart' as id_gen;
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../../account/presentation/providers/account_providers.dart';
import '../../../budget/domain/budget_service.dart';
import '../../../budget/presentation/providers/budget_providers.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../providers/transaction_form_providers.dart';
import '../providers/transaction_query_providers.dart';
import '../widgets/amount_display.dart';
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

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _amountController = AmountInputController();
  final _descriptionController = TextEditingController();
  final _descriptionFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _initialized = false;
  bool _counterpartyFocused = false;
  bool _showNumberPad = false;

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

  /// Hide number pad when user interacts with non-amount areas (type, date, category, transfer direction).
  void _hideNumberPad() {
    FocusScope.of(context).unfocus();
    if (_showNumberPad) setState(() => _showNumberPad = false);
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(transactionFormProvider);
    final isTransfer = formState.selectedType == TransactionType.transfer;
    final categoryType = formState.selectedType == TransactionType.income
        ? 'income'
        : 'expense';

    final canSave = _amountController.toDouble() > 0 &&
        (isTransfer || formState.categoryId != null);

    // Hide save bar while editing (description/counterparty) or while amount number pad is shown; "完成" only dismisses input, then user reviews and taps save.
    final isEditingText =
        _descriptionFocusNode.hasFocus || _counterpartyFocused;
    final showSaveBar = !isEditingText && !_showNumberPad;
    final showAmountDoneBar = _showNumberPad;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑交易' : '记一笔'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          const topSectionHeight = 130.0;
          const dividerHeight = 1.0;
          const saveBarHeight = 72.0;
          final reserveForBottomBar =
              (showSaveBar || showAmountDoneBar) ? saveBarHeight : 0.0;
          final numberPadMaxH = _showNumberPad
              ? (availableHeight -
                      topSectionHeight -
                      dividerHeight -
                      reserveForBottomBar)
                  .clamp(
                0.0,
                MediaQuery.sizeOf(context).height * 0.28,
              )
              : 0.0;

          return Column(
            children: [
              // Fixed top: type + amount (always visible when using number pad)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TypeSelector(
                        selected: formState.selectedType,
                        onChanged: (type) {
                          _hideNumberPad();
                          ref
                              .read(transactionFormProvider.notifier)
                              .setType(type);
                        },
                      ),
                    ),
                    GestureDetector(
                      onTap: _onAmountAreaTap,
                      behavior: HitTestBehavior.opaque,
                      child: AmountDisplay(
                        amountText: _amountController.value,
                        focused: _showNumberPad,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
              // Scrollable form: date, description, category, account (date/description above for focus)
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSection(
                        context,
                        title: '日期',
                        child: SingleChildScrollView(
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
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildSection(
                        context,
                        title: '描述',
                        child: TextField(
                          controller: _descriptionController,
                          focusNode: _descriptionFocusNode,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: '选填',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) {
                            ref
                                .read(transactionFormProvider.notifier)
                                .setDescription(val.isEmpty ? null : val);
                          },
                          onSubmitted: (_) =>
                              FocusScope.of(context).unfocus(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildSection(
                        context,
                        title: isTransfer ? '转账' : '分类',
                        child: isTransfer
                            ? TransferFields(
                                direction: formState.transferDirection,
                                counterparty: formState.counterparty,
                                onDirectionChanged: (dir) {
                                  _hideNumberPad();
                                  ref
                                      .read(transactionFormProvider.notifier)
                                      .setTransferDirection(dir);
                                },
                                onCounterpartyChanged: (val) {
                                  ref
                                      .read(transactionFormProvider.notifier)
                                      .setCounterparty(val);
                                },
                                onCounterpartyFocusChange:
                                    _onCounterpartyFocusChange,
                              )
                            : _buildCategorySection(
                                categoryType,
                                formState,
                                onCategoryTap: _hideNumberPad,
                              ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildAccountSectionWithTitle(context, formState),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
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
              if (showAmountDoneBar)
                _buildAmountDoneBar(),
              if (showSaveBar)
                _buildBottomSaveBar(canSave, formState),
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
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
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
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                minimumSize: const Size(0, 48),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: AppRadius.lgAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
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
  }) {
    final categoriesAsync = ref.watch(visibleCategoriesProvider(categoryType));
    final recentIdsAsync = ref.watch(recentCategoriesProvider);
    final recommendedNames = ref.watch(recommendedCategoryNamesProvider);

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
              onSelected: (id) {
                onCategoryTap?.call();
                ref.read(transactionFormProvider.notifier).setCategoryId(id);
              },
            ),
            if (recentCategories.isNotEmpty)
              const SizedBox(height: AppSpacing.sm),
            CategoryGrid(
              categories: categories,
              selectedId: formState.categoryId,
              onSelected: (id) {
                onCategoryTap?.call();
                ref.read(transactionFormProvider.notifier).setCategoryId(id);
              },
              recommendedNames: recommendedNames,
            ),
          ],
        );
      },
      loading: () => ShimmerPlaceholder.listPlaceholder(itemCount: 2),
      error: (e, _) => ErrorStateWidget(
        message: '加载分类失败: $e',
        onRetry: () => ref.invalidate(visibleCategoriesProvider(categoryType)),
      ),
    );
  }

  Widget _buildAccountSectionWithTitle(
    BuildContext context,
    TransactionFormState formState,
  ) {
    final multiAccountAsync = ref.watch(multiAccountEnabledProvider);

    return multiAccountAsync.when(
      data: (enabled) {
        if (!enabled) return const SizedBox.shrink();

        final accountsAsync = ref.watch(accountListProvider);
        return accountsAsync.when(
          data: (accounts) {
            return _buildSection(
              context,
              title: '账户',
              child: DropdownButtonFormField<String>(
                key: ValueKey(formState.accountId ?? ''),
                decoration: const InputDecoration(
                  labelText: '选择账户',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                isDense: false,
                initialValue: formState.accountId,
                items: accounts
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  ref.read(transactionFormProvider.notifier).setAccountId(id);
                },
              ),
            );
          },
          loading: () => ShimmerPlaceholder.listItem(),
          error: (e, _) => ErrorStateWidget(
            message: '加载账户失败: $e',
            onRetry: () => ref.invalidate(accountListProvider),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }

  Future<void> _save(TransactionFormState formState) async {
    // Validate amount
    if (_amountController.toDouble() <= 0) {
      _showError('请输入金额');
      return;
    }

    // Validate category for non-transfer
    if (formState.selectedType != TransactionType.transfer &&
        formState.categoryId == null) {
      _showError('请选择分类');
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
      _showError('保存失败：$e');
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
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
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
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                minimumSize: const Size(0, 48),
              ),
              child: const Text('保存'),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
