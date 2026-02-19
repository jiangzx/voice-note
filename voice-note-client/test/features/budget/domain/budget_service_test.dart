import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/budget/data/budget_dao.dart';
import 'package:suikouji/features/budget/data/budget_repository.dart';
import 'package:suikouji/features/budget/domain/budget_service.dart';
import 'package:suikouji/features/statistics/data/statistics_dao.dart';

import 'package:drift/drift.dart';

void main() {
  late AppDatabase db;
  late BudgetService service;
  late BudgetDao budgetDao;
  late String expenseCatId;
  late String accountId;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock the local notifications plugin to prevent MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'initialize') return true;
        if (methodCall.method == 'show') return null;
        return null;
      },
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    db = AppDatabase(NativeDatabase.memory());
    budgetDao = BudgetDao(db);
    final statsDao = StatisticsDao(db);
    final repo = BudgetRepository(budgetDao, statsDao);
    service = BudgetService(repo, prefs);

    // Get seeded data
    final cats = await db.select(db.categories).get();
    expenseCatId = cats.firstWhere((c) => c.type == 'expense').id;
    final accounts = await db.select(db.accounts).get();
    accountId = accounts.first.id;
  });

  tearDown(() async {
    await db.close();
  });

  group('checkAfterSave', () {
    test('does nothing when no budget is set', () async {
      // No budget set, should not throw
      await service.checkAfterSave(
        categoryId: expenseCatId,
        yearMonth: '2026-02',
      );
      // No assertion needed — just verifying no exception
    });

    test('does nothing when spending is below 80%', () async {
      // Set budget of 1000
      await budgetDao.upsertBudget(BudgetsCompanion.insert(
        id: 'b1',
        categoryId: expenseCatId,
        amount: 1000,
        yearMonth: '2026-02',
      ));

      // Add expense of 500 (50%)
      await _insertExpense(db, expenseCatId, accountId, 500.0);

      await service.checkAfterSave(
        categoryId: expenseCatId,
        yearMonth: '2026-02',
      );
      // Should not send notification (< 80%)
    });

    test('triggers warning when spending reaches 80%', () async {
      await budgetDao.upsertBudget(BudgetsCompanion.insert(
        id: 'b2',
        categoryId: expenseCatId,
        amount: 1000,
        yearMonth: '2026-03',
      ));

      // Add expense of 850 (85%)
      await _insertExpense(db, expenseCatId, accountId, 850.0,
          date: DateTime(2026, 3, 15));

      // This should trigger a notification (but we can't directly assert
      // notification was sent without mocking NotificationService).
      // We verify that the SharedPreferences key is set for deduplication.
      await service.checkAfterSave(
        categoryId: expenseCatId,
        yearMonth: '2026-03',
      );

      final prefs = await SharedPreferences.getInstance();
      final key = 'budget_alert_${expenseCatId}_2026-03_80';
      expect(prefs.getBool(key), true);
    });

    test('triggers exceeded alert when spending reaches 100%', () async {
      await budgetDao.upsertBudget(BudgetsCompanion.insert(
        id: 'b3',
        categoryId: expenseCatId,
        amount: 500,
        yearMonth: '2026-04',
      ));

      await _insertExpense(db, expenseCatId, accountId, 600.0,
          date: DateTime(2026, 4, 10));

      await service.checkAfterSave(
        categoryId: expenseCatId,
        yearMonth: '2026-04',
      );

      final prefs = await SharedPreferences.getInstance();
      final key = 'budget_alert_${expenseCatId}_2026-04_100';
      expect(prefs.getBool(key), true);
    });

    test('deduplicates notifications for same threshold', () async {
      await budgetDao.upsertBudget(BudgetsCompanion.insert(
        id: 'b4',
        categoryId: expenseCatId,
        amount: 100,
        yearMonth: '2026-05',
      ));

      await _insertExpense(db, expenseCatId, accountId, 90.0,
          date: DateTime(2026, 5, 1));

      // First call sets the key
      await service.checkAfterSave(
        categoryId: expenseCatId,
        yearMonth: '2026-05',
      );

      final prefs = await SharedPreferences.getInstance();
      final key = 'budget_alert_${expenseCatId}_2026-05_80';
      expect(prefs.getBool(key), true);

      // Second call should not throw (deduplication)
      await service.checkAfterSave(
        categoryId: expenseCatId,
        yearMonth: '2026-05',
      );
    });
  });

  group('currentYearMonth', () {
    test('returns current year-month in YYYY-MM format', () {
      final result = BudgetService.currentYearMonth();
      expect(result, matches(RegExp(r'^\d{4}-\d{2}$')));
    });
  });
}

Future<void> _insertExpense(
  AppDatabase db,
  String categoryId,
  String accountId,
  double amount, {
  DateTime? date,
}) async {
  await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'tx-${DateTime.now().microsecondsSinceEpoch}',
          type: 'expense',
          amount: amount,
          date: date ?? DateTime(2026, 2, 15),
          categoryId: Value(categoryId),
          accountId: accountId,
        ),
      );
}
