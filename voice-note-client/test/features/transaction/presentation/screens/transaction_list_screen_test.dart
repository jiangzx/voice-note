import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';
import 'package:suikouji/features/category/domain/entities/category_entity.dart';
import 'package:suikouji/features/category/domain/repositories/category_repository.dart';
import 'package:suikouji/features/category/presentation/providers/category_providers.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_entity.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_filter.dart';
import 'package:suikouji/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:suikouji/features/transaction/presentation/providers/transaction_form_providers.dart';
import 'package:suikouji/features/transaction/presentation/screens/transaction_list_screen.dart';
import 'package:suikouji/features/transaction/presentation/widgets/daily_group_header.dart';
import 'package:suikouji/features/transaction/presentation/widgets/filter_bar.dart';

void main() {
  group('DailyGroupHeader', () {
    testWidgets('shows date and subtotals', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: DailyGroupHeader(
              date: DateTime(2026, 2, 15),
              dailyIncome: 500,
              dailyExpense: 200,
            ),
          ),
        ),
      );

      expect(find.textContaining('500.00'), findsOneWidget);
      expect(find.textContaining('200.00'), findsOneWidget);
    });

    testWidgets('shows today label for current date', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: DailyGroupHeader(
              date: DateTime.now(),
              dailyIncome: 0,
              dailyExpense: 100,
            ),
          ),
        ),
      );

      expect(find.text('今天'), findsOneWidget);
    });
  });

  group('FilterBar', () {
    testWidgets('shows date and type chips', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: FilterBar(
              selectedDatePreset: DateRangePreset.thisMonth,
              selectedType: null,
              searchQuery: '',
              onDatePresetChanged: (_) {},
              onTypeChanged: (_) {},
              onSearchChanged: (_) {},
              onAdvancedFilter: () {},
            ),
          ),
        ),
      );

      expect(find.text('今天'), findsOneWidget);
      expect(find.text('本周'), findsOneWidget);
      expect(find.text('本月'), findsOneWidget);
      expect(find.text('本年'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
      expect(find.text('转账'), findsOneWidget);
    });
  });

  group('TransactionListScreen filter params', () {
    test('accepts filter parameters in constructor', () {
      const screen = TransactionListScreen(
        filterCategoryId: 'cat-123',
        filterDateFrom: '2026-01-01',
        filterDateTo: '2026-01-31',
      );

      expect(screen.filterCategoryId, 'cat-123');
      expect(screen.filterDateFrom, '2026-01-01');
      expect(screen.filterDateTo, '2026-01-31');
    });

    test('accepts null filter parameters', () {
      const screen = TransactionListScreen();

      expect(screen.filterCategoryId, isNull);
      expect(screen.filterDateFrom, isNull);
      expect(screen.filterDateTo, isNull);
    });
  });

  group('resolveDateRange', () {
    test('thisMonth returns full month range', () {
      final range = resolveDateRange(DateRangePreset.thisMonth);
      final now = DateTime.now();
      expect(range.from.month, now.month);
      expect(range.from.day, 1);
    });

    test('today returns single day range', () {
      final range = resolveDateRange(DateRangePreset.today);
      final now = DateTime.now();
      expect(range.from.day, now.day);
      expect(range.to.day, now.day);
    });
  });

  group('delete error handling', () {
    testWidgets('shows SnackBar when delete fails', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = _FailingTransactionRepository();
      final fakeCatRepo = _EmptyCategoryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWith((_) => fakeRepo),
            categoryRepositoryProvider.overrideWith((_) => fakeCatRepo),
          ],
          child: MaterialApp(
            theme: appTheme,
            home: const TransactionListScreen(),
          ),
        ),
      );

      // Wait for async providers to load
      await tester.pumpAndSettle();

      // The screen should show our test transaction
      expect(find.text('测试交易'), findsOneWidget);

      // Swipe left to trigger Dismissible
      await tester.drag(find.text('测试交易'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Tap "删除" in the confirm dialog
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // SnackBar should show error message
      expect(find.textContaining('删除失败'), findsOneWidget);
    });
  });
}

// ======================== Test Fakes ========================

class _FailingTransactionRepository implements TransactionRepository {
  @override
  Future<void> delete(String id) => throw Exception('DB constraint error');
  @override
  Future<void> deleteBatch(List<String> ids) =>
      throw Exception('DB constraint error');

  @override
  Future<List<DailyTransactionGroup>> getDailyGrouped(
    DateTime dateFrom,
    DateTime dateTo,
  ) async {
    final now = DateTime.now();
    return [
      DailyTransactionGroup(
        date: now,
        dailyIncome: 0,
        dailyExpense: 42,
        transactions: [
          TransactionEntity(
            id: 'tx-1',
            type: TransactionType.expense,
            amount: 42,
            date: now,
            description: '测试交易',
            categoryId: 'cat-1',
            accountId: 'acct-1',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    ];
  }

  @override
  Future<void> create(TransactionEntity t) async {}
  @override
  Future<void> createBatch(List<TransactionEntity> transactions) async {}
  @override
  Future<void> update(TransactionEntity t) async {}
  @override
  Future<TransactionEntity?> getById(String id) async => null;
  @override
  Future<List<TransactionEntity>> getFiltered(
    TransactionFilter f, {
    int? offset,
    int? limit,
  }) async => [];
  @override
  Future<TransactionSummary> getSummary(DateTime f, DateTime t) async =>
      const TransactionSummary(totalIncome: 0, totalExpense: 0);
  @override
  Future<List<TransactionEntity>> getRecent(int limit) async => [];
  @override
  Future<List<TransactionEntity>> getRecentPage(int limit, int offset) async =>
      [];
}

class _EmptyCategoryRepository implements CategoryRepository {
  @override
  Future<List<CategoryEntity>> getVisible(String type) async => [];
  @override
  Future<List<CategoryEntity>> getAll(String type) async => [];
  @override
  Future<CategoryEntity?> getById(String id) async => null;
  @override
  Future<void> create(CategoryEntity c) async {}
  @override
  Future<void> update(CategoryEntity c) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> reorder(List<String> ids) async {}
  @override
  Future<List<String>> getRecentlyUsed({int limit = 3}) async => [];
}
