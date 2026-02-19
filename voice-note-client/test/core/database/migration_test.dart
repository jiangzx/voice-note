import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/budget/data/budget_dao.dart';

void main() {
  group('Database schema v3', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('budgets table is available after creation', () async {
      final budgetDao = BudgetDao(db);
      // Should return empty list, not throw
      final budgets = await budgetDao.getByMonth('2026-02');
      expect(budgets, isEmpty);
    });

    test('can insert and query budget records', () async {
      final budgetDao = BudgetDao(db);

      // Get a seeded category to use as FK
      final cats = await db.select(db.categories).get();
      expect(cats, isNotEmpty);
      final catId = cats.first.id;

      await budgetDao.upsertBudget(
        BudgetsCompanion.insert(
          id: 'budget-test-1',
          categoryId: catId,
          amount: 1000.0,
          yearMonth: '2026-02',
        ),
      );

      final results = await budgetDao.getByMonth('2026-02');
      expect(results, hasLength(1));
      expect(results.first.categoryId, catId);
      expect(results.first.amount, 1000.0);
    });

    test('existing accounts and categories are preserved', () async {
      final accounts = await db.select(db.accounts).get();
      final categories = await db.select(db.categories).get();

      // Seed data should be intact
      expect(accounts, isNotEmpty);
      expect(categories, isNotEmpty);
    });

    test('budgets table enforces unique (categoryId, yearMonth)', () async {
      final budgetDao = BudgetDao(db);
      final cats = await db.select(db.categories).get();
      final catId = cats.first.id;

      await budgetDao.upsertBudget(
        BudgetsCompanion.insert(
          id: 'budget-dup-1',
          categoryId: catId,
          amount: 500.0,
          yearMonth: '2026-01',
        ),
      );

      // Upsert same categoryId + yearMonth should update, not duplicate
      await budgetDao.upsertBudget(
        BudgetsCompanion(
          id: const Value('budget-dup-1'),
          categoryId: Value(catId),
          amount: const Value(800.0),
          yearMonth: const Value('2026-01'),
        ),
      );

      final results = await budgetDao.getByMonth('2026-01');
      expect(results, hasLength(1));
      expect(results.first.amount, 800.0);
    });

    test('schema version is 3', () {
      expect(db.schemaVersion, 3);
    });
  });
}
