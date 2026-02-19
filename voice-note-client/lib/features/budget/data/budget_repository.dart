import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../statistics/data/statistics_dao.dart';
import '../domain/models/budget_status.dart';
import 'budget_dao.dart';

/// Repository providing budget operations with inheritance logic.
class BudgetRepository {
  BudgetRepository(this._budgetDao, this._statsDao);

  final BudgetDao _budgetDao;
  final StatisticsDao _statsDao;
  static const _uuid = Uuid();

  /// Get budgets for a month, with automatic inheritance from previous month.
  Future<List<Budget>> getOrInherit(String yearMonth) async {
    final budgets = await _budgetDao.getByMonth(yearMonth);
    if (budgets.isNotEmpty) return budgets;

    // Try inheriting from previous month
    final prevMonth = _previousMonth(yearMonth);
    final prevBudgets = await _budgetDao.getByMonth(prevMonth);
    if (prevBudgets.isEmpty) return [];

    // Copy previous month's budgets into this month
    final entries = prevBudgets
        .map(
          (b) => BudgetsCompanion.insert(
            id: _uuid.v4(),
            categoryId: b.categoryId,
            amount: b.amount,
            yearMonth: yearMonth,
          ),
        )
        .toList();

    await _budgetDao.insertAll(entries);
    return _budgetDao.getByMonth(yearMonth);
  }

  /// Get budget statuses with spent amounts for a month.
  Future<List<BudgetStatus>> getBudgetStatuses(String yearMonth) async {
    final budgets = await getOrInherit(yearMonth);
    if (budgets.isEmpty) return [];

    final dateRange = _monthDateRange(yearMonth);
    final results = <BudgetStatus>[];

    for (final budget in budgets) {
      final spent = await _statsDao.getCategoryExpenseTotal(
        categoryId: budget.categoryId,
        dateFrom: dateRange.start,
        dateTo: dateRange.end,
      );
      // Fetch category name via join
      results.add(BudgetStatus(
        categoryId: budget.categoryId,
        categoryName: '', // Filled by provider with category data
        budgetAmount: budget.amount,
        spentAmount: spent,
      ));
    }
    return results;
  }

  /// Check a single category's budget after transaction save.
  Future<BudgetStatus?> checkBudget(
    String categoryId,
    String yearMonth,
  ) async {
    final budget =
        await _budgetDao.getByCategoryAndMonth(categoryId, yearMonth);
    if (budget == null) return null;

    final dateRange = _monthDateRange(yearMonth);
    final spent = await _statsDao.getCategoryExpenseTotal(
      categoryId: categoryId,
      dateFrom: dateRange.start,
      dateTo: dateRange.end,
    );

    return BudgetStatus(
      categoryId: categoryId,
      categoryName: '',
      budgetAmount: budget.amount,
      spentAmount: spent,
    );
  }

  /// Save or update a budget entry.
  Future<void> saveBudget({
    required String categoryId,
    required double amount,
    required String yearMonth,
  }) async {
    final existing =
        await _budgetDao.getByCategoryAndMonth(categoryId, yearMonth);
    if (existing != null) {
      await _budgetDao.upsertBudget(
        BudgetsCompanion(
          id: Value(existing.id),
          categoryId: Value(categoryId),
          amount: Value(amount),
          yearMonth: Value(yearMonth),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await _budgetDao.upsertBudget(
        BudgetsCompanion.insert(
          id: _uuid.v4(),
          categoryId: categoryId,
          amount: amount,
          yearMonth: yearMonth,
        ),
      );
    }
  }

  /// Delete a budget entry.
  Future<void> deleteBudget(String categoryId, String yearMonth) =>
      _budgetDao.deleteByCategoryAndMonth(categoryId, yearMonth);

  String _previousMonth(String yearMonth) {
    final parts = yearMonth.split('-');
    var year = int.parse(parts[0]);
    var month = int.parse(parts[1]);
    month--;
    if (month < 1) {
      month = 12;
      year--;
    }
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  ({DateTime start, DateTime end}) _monthDateRange(String yearMonth) {
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1).subtract(const Duration(seconds: 1));
    return (start: start, end: end);
  }
}
