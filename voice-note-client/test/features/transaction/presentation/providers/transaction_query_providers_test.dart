import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/account/data/account_dao.dart';
import 'package:suikouji/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:suikouji/features/transaction/data/transaction_dao.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_filter.dart';
import 'package:suikouji/features/transaction/presentation/providers/transaction_form_providers.dart';
import 'package:suikouji/features/transaction/presentation/providers/transaction_query_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final txDao = TransactionDao(db);
    final accountDao = AccountDao(db);
    final repo = TransactionRepositoryImpl(txDao, accountDao);

    container = ProviderContainer(
      overrides: [transactionRepositoryProvider.overrideWith((_) => repo)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('transactionListProvider', () {
    test('returns empty list with no transactions', () async {
      final list = await container.read(
        transactionListProvider(const TransactionFilter()).future,
      );
      expect(list, isEmpty);
    });
  });

  group('summaryProvider', () {
    test('returns zero totals with no transactions', () async {
      final summary = await container.read(
        summaryProvider(DateTime(2026, 2, 1), DateTime(2026, 2, 28)).future,
      );
      expect(summary.totalIncome, 0);
      expect(summary.totalExpense, 0);
    });
  });

  group('recentTransactionsProvider', () {
    test('returns empty list with no transactions', () async {
      final recent = await container.read(recentTransactionsProvider.future);
      expect(recent, isEmpty);
    });
  });
}
