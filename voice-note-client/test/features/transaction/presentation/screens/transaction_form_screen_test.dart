import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';
import 'package:suikouji/features/account/domain/entities/account_entity.dart';
import 'package:suikouji/features/account/domain/repositories/account_repository.dart';
import 'package:suikouji/features/account/presentation/providers/account_providers.dart';
import 'package:suikouji/features/category/domain/entities/category_entity.dart';
import 'package:suikouji/features/category/domain/repositories/category_repository.dart';
import 'package:suikouji/features/category/presentation/providers/category_providers.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_entity.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_filter.dart';
import 'package:suikouji/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:suikouji/features/transaction/presentation/providers/transaction_form_providers.dart';
import 'package:suikouji/features/transaction/presentation/screens/transaction_form_screen.dart';
import 'package:suikouji/features/transaction/presentation/widgets/amount_display.dart';
import 'package:suikouji/features/transaction/presentation/widgets/number_pad.dart';
import 'package:suikouji/features/transaction/presentation/widgets/type_selector.dart';

void main() {
  group('AmountDisplay', () {
    testWidgets('shows currency symbol and amount', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const Scaffold(body: AmountDisplay(amountText: '42.5')),
        ),
      );

      expect(find.text('¥'), findsOneWidget);
      expect(find.text('42.5'), findsOneWidget);
    });

    testWidgets('shows 0 when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const Scaffold(body: AmountDisplay(amountText: '')),
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });
  });

  group('NumberPad', () {
    testWidgets('renders all keys', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: NumberPad(onKey: (_) {}, onBackspace: () {}),
          ),
        ),
      );

      for (final digit in [
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '.',
      ]) {
        expect(find.text(digit), findsOneWidget);
      }
      // Backspace icon
      expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    });

    testWidgets('calls onKey for digit tap', (tester) async {
      String? tappedKey;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: NumberPad(
              onKey: (key) => tappedKey = key,
              onBackspace: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('5'));
      expect(tappedKey, '5');
    });
  });

  group('TypeSelector', () {
    testWidgets('shows three segments', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(
            body: TypeSelector(
              selected: TransactionType.expense,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('支出'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
      expect(find.text('转账'), findsOneWidget);
    });
  });

  group('save error handling', () {
    testWidgets('shows SnackBar when save fails', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeRepo = _FailingSaveTransactionRepository();
      final fakeCatRepo = _EmptyCategoryRepository();
      final fakeAcctRepo = _FakeAccountRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transactionRepositoryProvider.overrideWith((_) => fakeRepo),
            categoryRepositoryProvider.overrideWith((_) => fakeCatRepo),
            accountRepositoryProvider.overrideWith((_) async => fakeAcctRepo),
          ],
          child: MaterialApp(
            theme: appTheme,
            home: const TransactionFormScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to transfer type (skips category validation)
      await tester.tap(find.text('转账'));
      await tester.pumpAndSettle();

      // Show number pad (hidden when type changed), then enter amount
      await tester.tap(find.byType(AmountDisplay));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();

      // Dismiss number pad with "完成", then tap save
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // SnackBar should show error message
      expect(find.textContaining('保存失败'), findsOneWidget);
    });
  });
}

// ======================== Test Fakes ========================

class _FailingSaveTransactionRepository implements TransactionRepository {
  @override
  Future<void> create(TransactionEntity t) =>
      throw Exception('DB constraint error');
  @override
  Future<void> createBatch(List<TransactionEntity> transactions) =>
      throw Exception('DB constraint error');
  @override
  Future<void> update(TransactionEntity t) =>
      throw Exception('DB constraint error');
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteBatch(List<String> ids) async {}
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
  Future<List<DailyTransactionGroup>> getDailyGrouped(
    DateTime f,
    DateTime t,
  ) async => [];
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

class _FakeAccountRepository implements AccountRepository {
  @override
  Future<List<AccountEntity>> getAll() async => [];
  @override
  Future<List<AccountEntity>> getActive() async => [];
  @override
  Future<AccountEntity?> getById(String id) async => null;
  @override
  Future<AccountEntity?> getDefault() async => null;
  @override
  Future<void> create(AccountEntity account) async {}
  @override
  Future<void> update(AccountEntity account) async {}
  @override
  Future<void> archive(String id) async {}
  @override
  Future<void> deleteById(String id) async {}
  @override
  Future<bool> isMultiAccountEnabled() async => false;
  @override
  Future<void> setMultiAccountEnabled({required bool enabled}) async {}
}
