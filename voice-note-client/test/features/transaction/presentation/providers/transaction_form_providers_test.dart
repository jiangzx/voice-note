import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_entity.dart';
import 'package:suikouji/features/transaction/presentation/providers/transaction_form_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('TransactionForm', () {
    test('initial state defaults to expense', () {
      final state = container.read(transactionFormProvider);
      expect(state.selectedType, TransactionType.expense);
      expect(state.amount, 0);
    });

    test('setType changes transaction type', () {
      container
          .read(transactionFormProvider.notifier)
          .setType(TransactionType.income);
      expect(
        container.read(transactionFormProvider).selectedType,
        TransactionType.income,
      );
    });

    test('setAmount changes amount', () {
      container.read(transactionFormProvider.notifier).setAmount(42.5);
      expect(container.read(transactionFormProvider).amount, 42.5);
    });

    test('setCategoryId sets category', () {
      container.read(transactionFormProvider.notifier).setCategoryId('cat-1');
      expect(container.read(transactionFormProvider).categoryId, 'cat-1');
    });

    test('setDate changes date', () {
      final date = DateTime(2026, 2, 15);
      container.read(transactionFormProvider.notifier).setDate(date);
      expect(container.read(transactionFormProvider).date, date);
    });

    test('setDescription sets description', () {
      container.read(transactionFormProvider.notifier).setDescription('午饭');
      expect(container.read(transactionFormProvider).description, '午饭');
    });

    test('setTransferDirection sets direction', () {
      container
          .read(transactionFormProvider.notifier)
          .setTransferDirection(TransferDirection.inbound);
      expect(
        container.read(transactionFormProvider).transferDirection,
        TransferDirection.inbound,
      );
    });

    test('transfer type supports category selection (required for save)', () {
      final notifier = container.read(transactionFormProvider.notifier);
      notifier.setType(TransactionType.transfer);
      notifier.setTransferDirection(TransferDirection.outbound);
      expect(container.read(transactionFormProvider).categoryId, isNull);

      notifier.setCategoryId('transfer-out-cat-id');
      expect(container.read(transactionFormProvider).categoryId, 'transfer-out-cat-id');
    });

    test('reset returns to default state', () {
      final notifier = container.read(transactionFormProvider.notifier);
      notifier.setType(TransactionType.income);
      notifier.setAmount(100);
      notifier.setCategoryId('cat-x');
      notifier.reset();

      final state = container.read(transactionFormProvider);
      expect(state.selectedType, TransactionType.expense);
      expect(state.amount, 0);
      expect(state.categoryId, equals(null));
    });

    test('loadFromEntity populates all fields', () {
      final now = DateTime.now();
      final entity = TransactionEntity(
        id: 'tx-1',
        type: TransactionType.transfer,
        amount: 500,
        date: DateTime(2026, 1, 20),
        accountId: 'acc-2',
        transferDirection: TransferDirection.outbound,
        counterparty: '小明',
        categoryId: null,
        description: '借款',
        createdAt: now,
        updatedAt: now,
      );

      container.read(transactionFormProvider.notifier).loadFromEntity(entity);
      final state = container.read(transactionFormProvider);

      expect(state.selectedType, TransactionType.transfer);
      expect(state.amount, 500);
      expect(state.date, DateTime(2026, 1, 20));
      expect(state.accountId, 'acc-2');
      expect(state.transferDirection, TransferDirection.outbound);
      expect(state.counterparty, '小明');
      expect(state.categoryId, equals(null));
      expect(state.description, '借款');
    });

    test('loadFromEntity followed by reset clears state', () {
      final now = DateTime.now();
      final entity = TransactionEntity(
        id: 'tx-1',
        type: TransactionType.income,
        amount: 1000,
        date: DateTime(2026, 2, 1),
        accountId: 'acc-1',
        categoryId: 'cat-1',
        createdAt: now,
        updatedAt: now,
      );

      final notifier = container.read(transactionFormProvider.notifier);
      notifier.loadFromEntity(entity);
      notifier.reset();

      final state = container.read(transactionFormProvider);
      expect(state.selectedType, TransactionType.expense);
      expect(state.amount, 0);
      expect(state.categoryId, equals(null));
      expect(state.accountId, equals(null));
    });
  });
}
