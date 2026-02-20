import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
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

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _amountController = AmountInputController();
  final _descriptionController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isEditing) {
        _initEditMode();
      } else {
        ref.read(transactionFormProvider.notifier).reset();
        _amountController.clear();
        _descriptionController.clear();
      }
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? '编辑交易' : '记一笔'),
      ),
      body: Column(
        children: [
          // Top section: scrollable form fields
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  // Type selector
                  Center(
                    child: TypeSelector(
                      selected: formState.selectedType,
                      onChanged: (type) {
                        ref
                            .read(transactionFormProvider.notifier)
                            .setType(type);
                      },
                    ),
                  ),
                  // Amount display
                  AmountDisplay(amountText: _amountController.value),
                  const Divider(),
                  // Category section or Transfer fields
                  if (isTransfer) ...[
                    TransferFields(
                      direction: formState.transferDirection,
                      counterparty: formState.counterparty,
                      onDirectionChanged: (dir) {
                        ref
                            .read(transactionFormProvider.notifier)
                            .setTransferDirection(dir);
                      },
                      onCounterpartyChanged: (val) {
                        ref
                            .read(transactionFormProvider.notifier)
                            .setCounterparty(val);
                      },
                    ),
                  ] else ...[
                    _buildCategorySection(categoryType, formState),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  // Date selection
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DateQuickSelect(
                      selected: formState.date,
                      onChanged: (date) {
                        ref
                            .read(transactionFormProvider.notifier)
                            .setDate(date);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Description
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: '描述 (可选)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) {
                      ref
                          .read(transactionFormProvider.notifier)
                          .setDescription(val.isEmpty ? null : val);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Account selection (multi-account mode)
                  _buildAccountSection(formState),
                ],
              ),
            ),
          ),
          // Bottom: Number pad
          const Divider(height: 1),
          NumberPad(
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
          // Bottom save button bar
          _buildBottomSaveBar(canSave, formState),
        ],
      ),
    );
  }

  Widget _buildCategorySection(
    String categoryType,
    TransactionFormState formState,
  ) {
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
                ref.read(transactionFormProvider.notifier).setCategoryId(id);
              },
            ),
            if (recentCategories.isNotEmpty)
              const SizedBox(height: AppSpacing.sm),
            CategoryGrid(
              categories: categories,
              selectedId: formState.categoryId,
              onSelected: (id) {
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

  Widget _buildAccountSection(TransactionFormState formState) {
    final multiAccountAsync = ref.watch(multiAccountEnabledProvider);

    return multiAccountAsync.when(
      data: (enabled) {
        if (!enabled) return const SizedBox.shrink();

        final accountsAsync = ref.watch(accountListProvider);
        return accountsAsync.when(
          data: (accounts) {
            return DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: '账户',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              initialValue: formState.accountId,
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: (id) {
                ref.read(transactionFormProvider.notifier).setAccountId(id);
              },
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSave ? () => _save(formState) : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: const Text('保存'),
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
