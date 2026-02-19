import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/budget/data/budget_dao.dart';

void main() {
  late AppDatabase db;
  late BudgetDao dao;
  late String catId1;
  late String catId2;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = BudgetDao(db);

    // Use seeded categories
    final cats = await db.select(db.categories).get();
    final expenseCats = cats.where((c) => c.type == 'expense').toList();
    catId1 = expenseCats[0].id;
    catId2 = expenseCats[1].id;
  });

  tearDown(() async {
    await db.close();
  });

  group('getByMonth', () {
    test('returns empty list when no budgets', () async {
      final result = await dao.getByMonth('2026-03');
      expect(result, isEmpty);
    });

    test('returns budgets for the specified month only', () async {
      await dao.upsertBudget(BudgetsCompanion.insert(
        id: 'b1', categoryId: catId1, amount: 1000, yearMonth: '2026-02',
      ));
      await dao.upsertBudget(BudgetsCompanion.insert(
        id: 'b2', categoryId: catId1, amount: 2000, yearMonth: '2026-03',
      ));

      final feb = await dao.getByMonth('2026-02');
      expect(feb, hasLength(1));
      expect(feb.first.amount, 1000);

      final mar = await dao.getByMonth('2026-03');
      expect(mar, hasLength(1));
      expect(mar.first.amount, 2000);
    });
  });

  group('getByCategoryAndMonth', () {
    test('returns null when not found', () async {
      final result = await dao.getByCategoryAndMonth(catId1, '2026-01');
      expect(result, isNull);
    });

    test('returns matching budget', () async {
      await dao.upsertBudget(BudgetsCompanion.insert(
        id: 'b3', categoryId: catId1, amount: 500, yearMonth: '2026-04',
      ));
      final result = await dao.getByCategoryAndMonth(catId1, '2026-04');
      expect(result, isNotNull);
      expect(result!.amount, 500);
    });
  });

  group('upsertBudget', () {
    test('inserts new budget', () async {
      await dao.upsertBudget(BudgetsCompanion.insert(
        id: 'b4', categoryId: catId1, amount: 800, yearMonth: '2026-05',
      ));
      final all = await dao.getByMonth('2026-05');
      expect(all, hasLength(1));
      expect(all.first.amount, 800);
    });

    test('updates existing budget on conflict', () async {
      await dao.upsertBudget(BudgetsCompanion.insert(
        id: 'b5', categoryId: catId2, amount: 600, yearMonth: '2026-06',
      ));
      await dao.upsertBudget(BudgetsCompanion(
        id: const Value('b5'),
        categoryId: Value(catId2),
        amount: const Value(900),
        yearMonth: const Value('2026-06'),
      ));

      final all = await dao.getByMonth('2026-06');
      expect(all, hasLength(1));
      expect(all.first.amount, 900);
    });
  });

  group('deleteById', () {
    test('removes the budget', () async {
      await dao.upsertBudget(BudgetsCompanion.insert(
        id: 'b6', categoryId: catId1, amount: 100, yearMonth: '2026-07',
      ));
      await dao.deleteById('b6');
      final result = await dao.getByMonth('2026-07');
      expect(result, isEmpty);
    });
  });

  group('deleteByCategoryAndMonth', () {
    test('removes matching budget', () async {
      await dao.upsertBudget(BudgetsCompanion.insert(
        id: 'b7', categoryId: catId2, amount: 300, yearMonth: '2026-08',
      ));
      await dao.deleteByCategoryAndMonth(catId2, '2026-08');
      final result = await dao.getByCategoryAndMonth(catId2, '2026-08');
      expect(result, isNull);
    });
  });

  group('insertAll', () {
    test('batch inserts multiple budgets', () async {
      final entries = [
        BudgetsCompanion.insert(
          id: 'b8', categoryId: catId1, amount: 400, yearMonth: '2026-09',
        ),
        BudgetsCompanion.insert(
          id: 'b9', categoryId: catId2, amount: 500, yearMonth: '2026-09',
        ),
      ];
      await dao.insertAll(entries);

      final results = await dao.getByMonth('2026-09');
      expect(results, hasLength(2));
    });
  });
}
