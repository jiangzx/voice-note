import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/statistics/data/statistics_dao.dart';
import 'package:suikouji/features/transaction/data/transaction_dao.dart';

/// Performance regression tests for database queries.
/// Ensures SQL aggregation and indexes keep queries fast at scale.
void main() {
  late AppDatabase db;
  late TransactionDao txDao;
  late StatisticsDao statsDao;
  const rowCount = 10000;

  setUpAll(() async {
    db = AppDatabase(NativeDatabase.memory());
    txDao = TransactionDao(db);
    statsDao = StatisticsDao(db);

    final categories = await db.select(db.categories).get();
    final accounts = await db.select(db.accounts).get();
    final rng = Random(42);
    final types = ['income', 'expense'];
    final baseDate = DateTime(2025);

    await db.batch((b) {
      for (var i = 0; i < rowCount; i++) {
        final type = types[rng.nextInt(2)];
        final date = baseDate.add(Duration(days: rng.nextInt(365)));
        b.insert(
          db.transactions,
          TransactionsCompanion.insert(
            id: 'bench-$i',
            type: type,
            amount: (rng.nextDouble() * 1000).roundToDouble(),
            currency: const Value('CNY'),
            date: date,
            accountId: accounts[rng.nextInt(accounts.length)].id,
            categoryId: Value(categories[rng.nextInt(categories.length)].id),
            isDraft: const Value(false),
            createdAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  });

  tearDownAll(() async {
    await db.close();
  });

  group('SQL aggregation performance ($rowCount rows)', () {
    test('getSummary completes under 20ms', () async {
      final sw = Stopwatch()..start();
      const runs = 50;
      for (var i = 0; i < runs; i++) {
        await txDao.getSummary(
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025, 12, 31),
        );
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / runs;
      expect(avgMs, lessThan(20));
    });

    test('getPeriodSummary completes under 20ms', () async {
      final sw = Stopwatch()..start();
      const runs = 50;
      for (var i = 0; i < runs; i++) {
        await statsDao.getPeriodSummary(
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025, 12, 31),
        );
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / runs;
      expect(avgMs, lessThan(20));
    });

    test('getFiltered with date+type completes under 20ms', () async {
      final sw = Stopwatch()..start();
      const runs = 50;
      for (var i = 0; i < runs; i++) {
        await txDao.getFiltered(
          dateFrom: DateTime(2025, 6),
          dateTo: DateTime(2025, 6, 30),
          type: 'expense',
        );
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / runs;
      expect(avgMs, lessThan(20));
    });

    test('getDailyTrend for full year completes under 50ms', () async {
      final sw = Stopwatch()..start();
      const runs = 50;
      for (var i = 0; i < runs; i++) {
        await statsDao.getDailyTrend(
          dateFrom: DateTime(2025),
          dateTo: DateTime(2025, 12, 31),
        );
      }
      sw.stop();
      final avgMs = sw.elapsedMilliseconds / runs;
      expect(avgMs, lessThan(50));
    });
  });

  group('Database indexes', () {
    test('all performance indexes exist', () async {
      final result = await db.customSelect(
        'SELECT name FROM sqlite_master '
        "WHERE type='index' AND name LIKE 'idx_tx_%'",
      ).get();
      final indexes = result.map((r) => r.read<String>('name')).toList();
      expect(
        indexes,
        containsAll([
          'idx_tx_date_type',
          'idx_tx_category',
          'idx_tx_account',
          'idx_tx_is_draft',
        ]),
      );
    });

    test('query planner uses index for aggregation', () async {
      final result = await db.customSelect(
        'EXPLAIN QUERY PLAN SELECT SUM(amount) FROM transactions '
        "WHERE date >= '2025-01-01' AND date <= '2025-12-31' "
        "AND is_draft = 0 AND type IN ('income', 'expense') "
        'GROUP BY type',
      ).get();
      final plan = result.map((r) => r.data.toString()).join('\n');
      expect(plan.toLowerCase(), contains('index'));
    });
  });
}
