import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/statistics/data/statistics_dao.dart';

void main() {
  late AppDatabase db;
  late StatisticsDao dao;
  late String expenseCatId;
  late String incomeCatId;
  late String accountId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = StatisticsDao(db);

    // Get seeded data
    final cats = await db.select(db.categories).get();
    expenseCatId =
        cats.firstWhere((c) => c.type == 'expense').id;
    incomeCatId =
        cats.firstWhere((c) => c.type == 'income').id;
    final accounts = await db.select(db.accounts).get();
    accountId = accounts.first.id;

    // Insert test transactions
    final now = DateTime(2026, 2, 15);
    final entries = [
      _txEntry('tx1', 'expense', 100.0, expenseCatId, accountId, now),
      _txEntry('tx2', 'expense', 200.0, expenseCatId, accountId,
          DateTime(2026, 2, 16)),
      _txEntry('tx3', 'income', 500.0, incomeCatId, accountId, now),
      _txEntry('tx4', 'income', 300.0, incomeCatId, accountId,
          DateTime(2026, 2, 17)),
      // Draft should be excluded
      _txEntry('tx5', 'expense', 999.0, expenseCatId, accountId, now,
          isDraft: true),
      // Transfer should be excluded from period summary
      _txEntry('tx6', 'transfer', 50.0, null, accountId, now),
    ];

    for (final entry in entries) {
      await db.into(db.transactions).insert(entry);
    }
  });

  tearDown(() async {
    await db.close();
  });

  group('getPeriodSummary', () {
    test('returns correct income and expense totals', () async {
      final result = await dao.getPeriodSummary(
        dateFrom: DateTime(2026, 2, 1),
        dateTo: DateTime(2026, 2, 28),
      );
      expect(result.totalExpense, 300.0); // 100 + 200 (draft excluded)
      expect(result.totalIncome, 800.0); // 500 + 300
    });

    test('excludes transactions outside date range', () async {
      final result = await dao.getPeriodSummary(
        dateFrom: DateTime(2026, 2, 16),
        dateTo: DateTime(2026, 2, 17),
      );
      expect(result.totalExpense, 200.0); // Only tx2
      expect(result.totalIncome, 300.0); // Only tx4
    });

    test('filters by account when specified', () async {
      final result = await dao.getPeriodSummary(
        dateFrom: DateTime(2026, 2, 1),
        dateTo: DateTime(2026, 2, 28),
        accountId: 'nonexistent',
      );
      expect(result.totalExpense, 0.0);
      expect(result.totalIncome, 0.0);
    });
  });

  group('getCategorySummary', () {
    test('returns expense categories grouped and sorted by amount', () async {
      final result = await dao.getCategorySummary(
        dateFrom: DateTime(2026, 2, 1),
        dateTo: DateTime(2026, 2, 28),
        type: 'expense',
      );
      expect(result, isNotEmpty);
      // All expense transactions are in the same category
      expect(result.first.totalAmount, 300.0);
      expect(result.first.categoryId, expenseCatId);
    });

    test('returns income categories', () async {
      final result = await dao.getCategorySummary(
        dateFrom: DateTime(2026, 2, 1),
        dateTo: DateTime(2026, 2, 28),
        type: 'income',
      );
      expect(result, isNotEmpty);
      expect(result.first.totalAmount, 800.0);
    });
  });

  group('getDailyTrend', () {
    test('returns daily income and expense', () async {
      final result = await dao.getDailyTrend(
        dateFrom: DateTime(2026, 2, 1),
        dateTo: DateTime(2026, 2, 28),
      );
      expect(result, isNotEmpty);

      // Verify total expense across all days matches 300 (100 + 200)
      final totalExpense =
          result.fold(0.0, (sum, r) => sum + r.expense);
      final totalIncome =
          result.fold(0.0, (sum, r) => sum + r.income);
      expect(totalExpense, 300.0);
      expect(totalIncome, 800.0);
    });
  });

  group('getMonthlyTrend', () {
    test('returns aggregated monthly data', () async {
      final result = await dao.getMonthlyTrend(
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 12, 31),
      );
      expect(result, isNotEmpty);

      final feb = result.where((r) => r.dateLabel == '2026-02').toList();
      expect(feb, isNotEmpty);
      expect(feb.first.expense, 300.0);
      expect(feb.first.income, 800.0);
    });
  });

  group('getCategoryExpenseTotal', () {
    test('returns total expense for a category', () async {
      final total = await dao.getCategoryExpenseTotal(
        categoryId: expenseCatId,
        dateFrom: DateTime(2026, 2, 1),
        dateTo: DateTime(2026, 2, 28),
      );
      expect(total, 300.0); // 100 + 200, draft excluded
    });

    test('returns 0 for category with no expenses', () async {
      final total = await dao.getCategoryExpenseTotal(
        categoryId: incomeCatId,
        dateFrom: DateTime(2026, 2, 1),
        dateTo: DateTime(2026, 2, 28),
      );
      expect(total, 0.0);
    });
  });
}

TransactionsCompanion _txEntry(
  String id,
  String type,
  double amount,
  String? categoryId,
  String accountId,
  DateTime date, {
  bool isDraft = false,
}) {
  return TransactionsCompanion.insert(
    id: id,
    type: type,
    amount: amount,
    date: date,
    categoryId: Value(categoryId),
    accountId: accountId,
    isDraft: Value(isDraft),
  );
}
