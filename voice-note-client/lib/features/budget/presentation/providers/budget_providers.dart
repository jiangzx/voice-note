import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/di/database_provider.dart';
import '../../../../core/di/network_providers.dart';
import '../../data/budget_repository.dart';
import '../../domain/budget_service.dart';
import '../../domain/models/budget_status.dart';

part 'budget_providers.g.dart';

@Riverpod(keepAlive: true)
BudgetRepository budgetRepository(Ref ref) {
  final dao = ref.watch(budgetDaoProvider);
  final statsDao = ref.watch(statisticsDaoProvider);
  return BudgetRepository(dao, statsDao);
}

@Riverpod(keepAlive: true)
BudgetService budgetService(Ref ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return BudgetService(repo, prefs);
}

/// Budget status enriched with category icon and color for UI.
class BudgetStatusWithCategory {
  const BudgetStatusWithCategory({
    required this.status,
    required this.icon,
    required this.color,
  });

  final BudgetStatus status;
  final String icon;
  final String color;
}

@riverpod
Future<List<BudgetStatusWithCategory>> currentMonthBudgetStatuses(Ref ref) async {
  final repo = ref.watch(budgetRepositoryProvider);
  final categoryDao = ref.watch(categoryDaoProvider);
  final yearMonth = BudgetService.currentYearMonth();
  final statuses = await repo.getBudgetStatuses(yearMonth);
  if (statuses.isEmpty) return [];

  final expenseCats = await categoryDao.getByType('expense');
  final catMap = {for (final c in expenseCats) c.id: c};

  return statuses.map((s) {
    final cat = catMap[s.categoryId];
    return BudgetStatusWithCategory(
      status: BudgetStatus(
        categoryId: s.categoryId,
        categoryName: cat?.name ?? '未知分类',
        budgetAmount: s.budgetAmount,
        spentAmount: s.spentAmount,
      ),
      icon: cat?.icon ?? 'material:category',
      color: cat?.color ?? 'FF9E9E9E',
    );
  }).toList();
}

/// Existing budget amounts by category for current month (for edit form).
@riverpod
Future<Map<String, double>> currentMonthBudgetAmounts(Ref ref) async {
  final repo = ref.watch(budgetRepositoryProvider);
  final yearMonth = BudgetService.currentYearMonth();
  final budgets = await repo.getOrInherit(yearMonth);
  return {for (final b in budgets) b.categoryId: b.amount};
}

/// Summary: total budget, total spent, total remaining for current month.
@riverpod
Future<({double totalBudget, double totalSpent, double totalRemaining})>
    budgetSummary(Ref ref) async {
  final items = await ref.watch(currentMonthBudgetStatusesProvider.future);
  var totalBudget = 0.0;
  var totalSpent = 0.0;
  for (final item in items) {
    totalBudget += item.status.budgetAmount;
    totalSpent += item.status.spentAmount;
  }
  return (
    totalBudget: totalBudget,
    totalSpent: totalSpent,
    totalRemaining: totalBudget - totalSpent,
  );
}
