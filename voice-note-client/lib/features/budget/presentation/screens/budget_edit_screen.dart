import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/utils/color_utils.dart';
import '../../../../core/utils/icon_utils.dart';
import '../../../../shared/error_copy.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../category/domain/entities/category_entity.dart';
import '../../../category/presentation/providers/category_providers.dart';
import '../../domain/budget_service.dart';
import '../providers/budget_providers.dart';

/// Edit budget screen: set amount per expense category for current month.
class BudgetEditScreen extends ConsumerStatefulWidget {
  const BudgetEditScreen({super.key});

  @override
  ConsumerState<BudgetEditScreen> createState() => _BudgetEditScreenState();
}

class _BudgetEditScreenState extends ConsumerState<BudgetEditScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _controllersInitialized = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllers(
    List<CategoryEntity> categories,
    Map<String, double> amounts,
  ) {
    if (_controllersInitialized) return;
    _controllersInitialized = true;
    for (final cat in categories) {
      final amount = amounts[cat.id];
      _controllers[cat.id] = TextEditingController(
        text: amount != null && amount > 0 ? amount.toStringAsFixed(0) : '',
      );
    }
    setState(() {});
  }

  Future<void> _save() async {
    final repo = ref.read(budgetRepositoryProvider);
    final yearMonth = BudgetService.currentYearMonth();
    final categories =
        await ref.read(visibleCategoriesProvider('expense').future);

    for (final cat in categories) {
      final ctrl = _controllers[cat.id];
      final text = ctrl?.text.trim() ?? '';
      final amount = double.tryParse(text);

      if (amount == null || amount <= 0) {
        await repo.deleteBudget(cat.id, yearMonth);
      } else {
        await repo.saveBudget(
          categoryId: cat.id,
          amount: amount,
          yearMonth: yearMonth,
        );
      }
    }

    ref.invalidate(currentMonthBudgetStatusesProvider);
    ref.invalidate(budgetSummaryProvider);
    ref.invalidate(currentMonthBudgetAmountsProvider);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(visibleCategoriesProvider('expense'));
    final amountsAsync = ref.watch(currentMonthBudgetAmountsProvider);

    final canSave = categoriesAsync.hasValue && amountsAsync.hasValue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑预算'),
      ),
      body: Column(
        children: [
          Expanded(
            child: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(
              child: Text('暂无支出分类，请先添加分类'),
            );
          }

          return amountsAsync.when(
            data: (amounts) {
              if (!_controllersInitialized) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _initControllers(categories, amounts);
                });
                return ShimmerPlaceholder.listPlaceholder(
                  itemCount: categories.length,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final ctrl = _controllers[cat.id];
                  if (ctrl == null) return const SizedBox.shrink();
                  return _CategoryBudgetRow(
                    key: ValueKey(cat.id),
                    category: cat,
                    controller: ctrl,
                  );
                },
              );
            },
            loading: () => ShimmerPlaceholder.listPlaceholder(itemCount: 8),
            error: (e, st) => ErrorStateWidget(
              message: ErrorCopy.loadFailed,
              onRetry: () =>
                  ref.invalidate(currentMonthBudgetAmountsProvider),
            ),
          );
        },
        loading: () => ShimmerPlaceholder.listPlaceholder(itemCount: 8),
        error: (e, st) => ErrorStateWidget(
          message: ErrorCopy.loadFailed,
          onRetry: () => ref.invalidate(visibleCategoriesProvider('expense')),
        ),
            ),
          ),
          _buildBottomSaveBar(canSave),
        ],
      ),
    );
  }

  Widget _buildBottomSaveBar(bool canSave) {
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
            onPressed: canSave
                ? () async {
                    final cats = await ref.read(
                      visibleCategoriesProvider('expense').future,
                    );
                    final amounts = await ref.read(
                      currentMonthBudgetAmountsProvider.future,
                    );
                    if (!_controllersInitialized) {
                      _initControllers(cats, amounts);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _save();
                      });
                      return;
                    }
                    await _save();
                  }
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            child: const Text('保存'),
          ),
        ),
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    super.key,
    required this.category,
    required this.controller,
  });

  final CategoryEntity category;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = colorFromArgbHex(category.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withAlpha(64),
            child: iconFromString(category.icon, size: AppIconSize.md),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              category.name,
              style: theme.textTheme.titleSmall,
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: '金额',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
