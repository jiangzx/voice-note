import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

part 'budget_dao.g.dart';

@DriftAccessor(tables: [Budgets, Categories])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.db);

  /// Get all budgets for a specific month.
  Future<List<Budget>> getByMonth(String yearMonth) =>
      (select(budgets)..where((b) => b.yearMonth.equals(yearMonth))).get();

  /// Get a single budget by category and month.
  Future<Budget?> getByCategoryAndMonth(
    String categoryId,
    String yearMonth,
  ) =>
      (select(budgets)
            ..where(
              (b) =>
                  b.categoryId.equals(categoryId) &
                  b.yearMonth.equals(yearMonth),
            ))
          .getSingleOrNull();

  /// Upsert: insert or update on conflict.
  Future<void> upsertBudget(BudgetsCompanion entry) =>
      into(budgets).insertOnConflictUpdate(entry);

  /// Delete a budget by ID.
  Future<int> deleteById(String id) =>
      (delete(budgets)..where((b) => b.id.equals(id))).go();

  /// Delete budget by category and month.
  Future<int> deleteByCategoryAndMonth(
    String categoryId,
    String yearMonth,
  ) =>
      (delete(budgets)
            ..where(
              (b) =>
                  b.categoryId.equals(categoryId) &
                  b.yearMonth.equals(yearMonth),
            ))
          .go();

  /// Batch insert budgets (for inheritance).
  Future<void> insertAll(List<BudgetsCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(budgets, entries);
    });
  }
}
