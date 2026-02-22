import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/account/data/account_dao.dart';
import 'package:suikouji/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:suikouji/features/transaction/data/transaction_dao.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_filter.dart';

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl repo;
  late String defaultAccountId;
  late String expenseCategoryId;
  late String incomeCategoryId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final txDao = TransactionDao(db);
    final accountDao = AccountDao(db);
    repo = TransactionRepositoryImpl(txDao, accountDao);

    final account = await (db.select(
      db.accounts,
    )..where((a) => a.isPreset.equals(true))).getSingle();
    defaultAccountId = account.id;

    final expCat =
        await (db.select(db.categories)
              ..where((c) => c.type.equals('expense'))
              ..limit(1))
            .getSingle();
    expenseCategoryId = expCat.id;

    final incCat =
        await (db.select(db.categories)
              ..where((c) => c.type.equals('income'))
              ..limit(1))
            .getSingle();
    incomeCategoryId = incCat.id;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTx({
    required String id,
    required String type,
    required double amount,
    required DateTime date,
    String? categoryId,
    String? description,
    String? transferDirection,
  }) async {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: id,
            type: type,
            amount: amount,
            date: date,
            categoryId: drift.Value(categoryId),
            accountId: defaultAccountId,
            description: drift.Value(description),
            transferDirection: drift.Value(transferDirection),
          ),
        );
  }

  group('getFiltered', () {
    test('returns all when no filter', () async {
      await insertTx(
        id: 'tx-1',
        type: 'expense',
        amount: 35,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );
      await insertTx(
        id: 'tx-2',
        type: 'income',
        amount: 1000,
        date: DateTime(2026, 2, 15),
        categoryId: incomeCategoryId,
      );

      final results = await repo.getFiltered(const TransactionFilter());
      expect(results.length, 2);
    });

    test('sorts by date DESC then createdAt DESC', () async {
      await insertTx(
        id: 'old',
        type: 'expense',
        amount: 10,
        date: DateTime(2026, 2, 10),
        categoryId: expenseCategoryId,
      );
      await insertTx(
        id: 'new',
        type: 'expense',
        amount: 20,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );

      final results = await repo.getFiltered(const TransactionFilter());
      expect(results.first.id, 'new');
    });

    test('filters by date range', () async {
      await insertTx(
        id: 'feb10',
        type: 'expense',
        amount: 10,
        date: DateTime(2026, 2, 10),
        categoryId: expenseCategoryId,
      );
      await insertTx(
        id: 'feb15',
        type: 'expense',
        amount: 20,
        date: DateTime(2026, 2, 15),
        categoryId: expenseCategoryId,
      );

      final results = await repo.getFiltered(
        TransactionFilter(
          dateFrom: DateTime(2026, 2, 14),
          dateTo: DateTime(2026, 2, 16),
        ),
      );
      expect(results.length, 1);
      expect(results.first.id, 'feb15');
    });

    test('filters by category', () async {
      await insertTx(
        id: 'exp',
        type: 'expense',
        amount: 10,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );
      await insertTx(
        id: 'inc',
        type: 'income',
        amount: 1000,
        date: DateTime(2026, 2, 16),
        categoryId: incomeCategoryId,
      );

      final results = await repo.getFiltered(
        TransactionFilter(categoryIds: [expenseCategoryId]),
      );
      expect(results.length, 1);
      expect(results.first.id, 'exp');
    });

    test('filters by amount range', () async {
      await insertTx(
        id: 'small',
        type: 'expense',
        amount: 10,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );
      await insertTx(
        id: 'big',
        type: 'expense',
        amount: 500,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );

      final results = await repo.getFiltered(
        const TransactionFilter(minAmount: 100, maxAmount: 600),
      );
      expect(results.length, 1);
      expect(results.first.id, 'big');
    });

    test('filters by account', () async {
      // All test transactions use the default account, so filtering by it
      // should return them while a bogus ID returns none
      await insertTx(
        id: 'acct-tx',
        type: 'expense',
        amount: 10,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );

      final withMatch = await repo.getFiltered(
        TransactionFilter(accountId: defaultAccountId),
      );
      expect(withMatch.length, 1);

      final withoutMatch = await repo.getFiltered(
        const TransactionFilter(accountId: 'nonexistent-account'),
      );
      expect(withoutMatch, isEmpty);
    });

    test('keyword search returns empty when no match', () async {
      await insertTx(
        id: 'x',
        type: 'expense',
        amount: 10,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
        description: '早餐',
      );

      final results = await repo.getFiltered(
        const TransactionFilter(keyword: '不存在的关键词'),
      );
      expect(results, isEmpty);
    });

    test('filters by keyword in description', () async {
      await insertTx(
        id: 'lunch',
        type: 'expense',
        amount: 35,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
        description: '午饭',
      );
      await insertTx(
        id: 'taxi',
        type: 'expense',
        amount: 20,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
        description: '打车',
      );

      final results = await repo.getFiltered(
        const TransactionFilter(keyword: '午饭'),
      );
      expect(results.length, 1);
      expect(results.first.id, 'lunch');
    });

    test('filters by type', () async {
      await insertTx(
        id: 'exp',
        type: 'expense',
        amount: 10,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );
      await insertTx(
        id: 'inc',
        type: 'income',
        amount: 1000,
        date: DateTime(2026, 2, 16),
        categoryId: incomeCategoryId,
      );

      final results = await repo.getFiltered(
        const TransactionFilter(type: 'income'),
      );
      expect(results.length, 1);
      expect(results.first.id, 'inc');
    });

    test('combines multiple filters with AND', () async {
      await insertTx(
        id: 'match',
        type: 'expense',
        amount: 200,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
        description: '午饭AA',
      );
      await insertTx(
        id: 'no-match-date',
        type: 'expense',
        amount: 200,
        date: DateTime(2026, 1, 10),
        categoryId: expenseCategoryId,
        description: '午饭AA',
      );
      await insertTx(
        id: 'no-match-keyword',
        type: 'expense',
        amount: 200,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
        description: '打车',
      );

      final results = await repo.getFiltered(
        TransactionFilter(
          dateFrom: DateTime(2026, 2, 1),
          dateTo: DateTime(2026, 2, 28),
          keyword: '午饭',
        ),
      );
      expect(results.length, 1);
      expect(results.first.id, 'match');
    });
  });

  group('getSummary', () {
    test('returns income and expense totals', () async {
      await insertTx(
        id: 'exp1',
        type: 'expense',
        amount: 100,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );
      await insertTx(
        id: 'inc1',
        type: 'income',
        amount: 200,
        date: DateTime(2026, 2, 16),
        categoryId: incomeCategoryId,
      );

      final summary = await repo.getSummary(
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
      );
      expect(summary.totalExpense, 100);
      expect(summary.totalIncome, 200);
    });

    test('excludes transfers from summary', () async {
      await insertTx(
        id: 'exp',
        type: 'expense',
        amount: 100,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );
      await insertTx(
        id: 'inc',
        type: 'income',
        amount: 200,
        date: DateTime(2026, 2, 16),
        categoryId: incomeCategoryId,
      );
      await insertTx(
        id: 'transfer',
        type: 'transfer',
        amount: 500,
        date: DateTime(2026, 2, 16),
        transferDirection: 'in',
      );

      final summary = await repo.getSummary(
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
      );
      expect(summary.totalIncome, 200);
      expect(summary.totalExpense, 100);
    });
  });

  group('getRecent', () {
    test('returns up to N most recent transactions (by createdAt, newest first)', () async {
      // Insert in ascending date order so latest-created = latest date (amount 10).
      for (var i = 0; i < 10; i++) {
        await insertTx(
          id: 'tx-$i',
          type: 'expense',
          amount: 10.0 + i,
          date: DateTime(2026, 2, 7 + i),
          categoryId: expenseCategoryId,
        );
      }

      final recent = await repo.getRecent(5);
      expect(recent.length, 5);
      expect(recent.first.amount, 19); // last inserted = newest createdAt
    });
  });

  group('getDailyGrouped', () {
    test('groups transactions by day with subtotals', () async {
      await insertTx(
        id: 'day1-exp',
        type: 'expense',
        amount: 30,
        date: DateTime(2026, 2, 15),
        categoryId: expenseCategoryId,
      );
      await insertTx(
        id: 'day1-inc',
        type: 'income',
        amount: 100,
        date: DateTime(2026, 2, 15),
        categoryId: incomeCategoryId,
      );
      await insertTx(
        id: 'day2-exp',
        type: 'expense',
        amount: 50,
        date: DateTime(2026, 2, 16),
        categoryId: expenseCategoryId,
      );

      final groups = await repo.getDailyGrouped(
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
      );
      expect(groups.length, 2);

      // Sorted DESC: day2 first
      expect(groups[0].date, DateTime(2026, 2, 16));
      expect(groups[0].dailyExpense, 50);
      expect(groups[1].date, DateTime(2026, 2, 15));
      expect(groups[1].dailyIncome, 100);
      expect(groups[1].dailyExpense, 30);
    });

    test('transfer does not count in daily subtotals', () async {
      await insertTx(
        id: 'tr',
        type: 'transfer',
        amount: 500,
        date: DateTime(2026, 2, 16),
        transferDirection: 'out',
      );

      final groups = await repo.getDailyGrouped(
        DateTime(2026, 2, 1),
        DateTime(2026, 2, 28),
      );
      expect(groups.length, 1);
      expect(groups[0].dailyIncome, 0);
      expect(groups[0].dailyExpense, 0);
    });
  });
}
