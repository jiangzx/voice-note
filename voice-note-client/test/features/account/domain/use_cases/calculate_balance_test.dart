import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/account/domain/use_cases/calculate_balance_use_case.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_entity.dart';

void main() {
  const useCase = CalculateBalanceUseCase();
  final now = DateTime.now();

  TransactionEntity tx({
    required TransactionType type,
    required double amount,
    TransferDirection? transferDirection,
    bool isDraft = false,
  }) {
    return TransactionEntity(
      id: 'tx-${now.microsecondsSinceEpoch}',
      type: type,
      amount: amount,
      date: now,
      accountId: 'acc-1',
      transferDirection: transferDirection,
      isDraft: isDraft,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('CalculateBalanceUseCase', () {
    test('returns initial balance when no transactions', () {
      final result = useCase(initialBalance: 1000, transactions: []);
      expect(result, 1000.0);
    });

    test('adds income to balance', () {
      final result = useCase(
        initialBalance: 0,
        transactions: [
          tx(type: TransactionType.income, amount: 500),
          tx(type: TransactionType.income, amount: 300),
        ],
      );
      expect(result, 800.0);
    });

    test('subtracts expense from balance', () {
      final result = useCase(
        initialBalance: 1000,
        transactions: [
          tx(type: TransactionType.expense, amount: 200),
          tx(type: TransactionType.expense, amount: 100),
        ],
      );
      expect(result, 700.0);
    });

    test('handles mixed transactions correctly', () {
      // initial=0, income=1000, expense=300, transfer_out=200, transfer_in=100
      // expected: 0 + 1000 - 300 - 200 + 100 = 600
      final result = useCase(
        initialBalance: 0,
        transactions: [
          tx(type: TransactionType.income, amount: 1000),
          tx(type: TransactionType.expense, amount: 300),
          tx(
            type: TransactionType.transfer,
            amount: 200,
            transferDirection: TransferDirection.outbound,
          ),
          tx(
            type: TransactionType.transfer,
            amount: 100,
            transferDirection: TransferDirection.inbound,
          ),
        ],
      );
      expect(result, 600.0);
    });

    test('includes initial balance in calculation', () {
      final result = useCase(
        initialBalance: 5000,
        transactions: [tx(type: TransactionType.expense, amount: 300)],
      );
      expect(result, 4700.0);
    });

    test('skips draft transactions', () {
      final result = useCase(
        initialBalance: 1000,
        transactions: [
          tx(type: TransactionType.expense, amount: 500, isDraft: true),
          tx(type: TransactionType.expense, amount: 200),
        ],
      );
      expect(result, 800.0);
    });
  });
}
