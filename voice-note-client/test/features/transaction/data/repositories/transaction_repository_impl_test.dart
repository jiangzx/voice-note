import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/features/account/data/account_dao.dart';
import 'package:suikouji/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:suikouji/features/transaction/data/transaction_dao.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_entity.dart';

void main() {
  late AppDatabase db;
  late TransactionRepositoryImpl repo;
  late String defaultAccountId;
  late String defaultCategoryId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final txDao = TransactionDao(db);
    final accountDao = AccountDao(db);
    repo = TransactionRepositoryImpl(txDao, accountDao);

    // Retrieve seeded defaults
    final account = await (db.select(
      db.accounts,
    )..where((a) => a.isPreset.equals(true))).getSingle();
    defaultAccountId = account.id;

    final category =
        await (db.select(db.categories)
              ..where((c) => c.type.equals('expense'))
              ..limit(1))
            .getSingle();
    defaultCategoryId = category.id;
  });

  tearDown(() async {
    await db.close();
  });

  TransactionEntity expense({
    String id = 'tx-1',
    double amount = 35,
    String? categoryId,
    String? accountId,
  }) {
    final now = DateTime.now();
    return TransactionEntity(
      id: id,
      type: TransactionType.expense,
      amount: amount,
      date: now,
      categoryId: categoryId ?? defaultCategoryId,
      accountId: accountId ?? defaultAccountId,
      createdAt: now,
      updatedAt: now,
    );
  }

  TransactionEntity income({
    String id = 'tx-income',
    double amount = 1000,
    String? categoryId,
  }) {
    final now = DateTime.now();
    return TransactionEntity(
      id: id,
      type: TransactionType.income,
      amount: amount,
      date: now,
      categoryId: categoryId ?? defaultCategoryId,
      accountId: defaultAccountId,
      createdAt: now,
      updatedAt: now,
    );
  }

  TransactionEntity transfer({
    String id = 'tx-transfer',
    double amount = 500,
    TransferDirection direction = TransferDirection.outbound,
    String? counterparty,
  }) {
    final now = DateTime.now();
    return TransactionEntity(
      id: id,
      type: TransactionType.transfer,
      amount: amount,
      date: now,
      accountId: defaultAccountId,
      transferDirection: direction,
      counterparty: counterparty,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('create', () {
    test('creates an expense transaction', () async {
      await repo.create(expense());
      final saved = await repo.getById('tx-1');
      expect(saved, isNot(null));
      expect(saved!.type, TransactionType.expense);
      expect(saved.amount, 35);
    });

    test('creates an income transaction', () async {
      await repo.create(income());
      final saved = await repo.getById('tx-income');
      expect(saved, isNot(null));
      expect(saved!.type, TransactionType.income);
    });

    test('creates a transfer transaction without category', () async {
      await repo.create(transfer());
      final saved = await repo.getById('tx-transfer');
      expect(saved, isNot(null));
      expect(saved!.type, TransactionType.transfer);
      expect(saved.transferDirection, TransferDirection.outbound);
    });

    test('creates a transfer with counterparty', () async {
      await repo.create(
        transfer(
          id: 'tx-with-cp',
          direction: TransferDirection.inbound,
          counterparty: '小明',
        ),
      );
      final saved = await repo.getById('tx-with-cp');
      expect(saved, isNot(null));
      expect(saved!.transferDirection, TransferDirection.inbound);
      expect(saved.counterparty, '小明');
    });

    test('persists null description', () async {
      await repo.create(expense());
      final saved = await repo.getById('tx-1');
      expect(saved!.description, equals(null));
    });

    test('new transaction has sync_status=local and remote_id=null', () async {
      await repo.create(expense());
      // Read raw row to check sync fields
      final row = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('tx-1'))).getSingle();
      expect(row.syncStatus, 'local');
      expect(row.remoteId, equals(null));
    });

    test('defaults currency to CNY', () async {
      await repo.create(expense());
      final saved = await repo.getById('tx-1');
      expect(saved!.currency, 'CNY');
    });

    test('rejects zero amount', () {
      expect(
        () => repo.create(expense(amount: 0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects negative amount', () {
      expect(
        () => repo.create(expense(amount: -10)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects expense without category', () {
      final now = DateTime.now();
      expect(
        () => repo.create(
          TransactionEntity(
            id: 'no-cat',
            type: TransactionType.expense,
            amount: 10,
            date: now,
            accountId: defaultAccountId,
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('update', () {
    test('updates amount', () async {
      await repo.create(expense());
      final existing = await repo.getById('tx-1');
      await repo.update(existing!.copyWith(amount: 45));
      final updated = await repo.getById('tx-1');
      expect(updated!.amount, 45);
    });

    test('automatically refreshes updatedAt', () async {
      await repo.create(expense());
      final existing = await repo.getById('tx-1');
      final originalUpdatedAt = existing!.updatedAt;

      // Small delay to ensure DateTime.now() differs
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.update(existing.copyWith(amount: 99));

      final updated = await repo.getById('tx-1');
      expect(
        updated!.updatedAt.isAfter(originalUpdatedAt) ||
            updated.updatedAt.isAtSameMomentAs(originalUpdatedAt),
        isTrue,
      );
    });
  });

  group('delete', () {
    test('removes the transaction', () async {
      await repo.create(expense());
      await repo.delete('tx-1');
      final result = await repo.getById('tx-1');
      expect(result, equals(null));
    });

    test('clears linked_transaction_id on partner', () async {
      await repo.create(transfer(id: 'tx-a'));
      await repo.create(
        transfer(
          id: 'tx-b',
          direction: TransferDirection.inbound,
        ).copyWith(linkedTransactionId: () => 'tx-a'),
      );

      await repo.delete('tx-a');
      final partner = await repo.getById('tx-b');
      expect(partner, isNot(null));
      expect(partner!.linkedTransactionId, equals(null));
    });
  });
}
