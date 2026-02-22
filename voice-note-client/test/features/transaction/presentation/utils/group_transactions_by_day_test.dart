import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/transaction/domain/entities/transaction_entity.dart';
import 'package:suikouji/features/transaction/presentation/utils/group_transactions_by_day.dart';

void main() {
  final base = DateTime(2025, 2, 20);
  TransactionEntity tx({
    required String id,
    required TransactionType type,
    required double amount,
    DateTime? date,
    TransferDirection? transferDirection,
  }) {
    return TransactionEntity(
      id: id,
      type: type,
      amount: amount,
      date: date ?? base,
      accountId: 'a1',
      createdAt: base,
      updatedAt: base,
      transferDirection: transferDirection,
    );
  }

  group('groupTransactionsByDay', () {
    test('empty list returns empty', () {
      expect(groupTransactionsByDay([]), isEmpty);
    });

    test('single income adds to dailyIncome only', () {
      final list = [
        tx(id: '1', type: TransactionType.income, amount: 100),
      ];
      final groups = groupTransactionsByDay(list);
      expect(groups.length, 1);
      expect(groups[0].dailyIncome, 100);
      expect(groups[0].dailyExpense, 0);
    });

    test('single expense adds to dailyExpense only', () {
      final list = [
        tx(id: '1', type: TransactionType.expense, amount: 50),
      ];
      final groups = groupTransactionsByDay(list);
      expect(groups.length, 1);
      expect(groups[0].dailyIncome, 0);
      expect(groups[0].dailyExpense, 50);
    });

    test('transfer inbound adds to dailyIncome', () {
      final list = [
        tx(
          id: '1',
          type: TransactionType.transfer,
          amount: 80,
          transferDirection: TransferDirection.inbound,
        ),
      ];
      final groups = groupTransactionsByDay(list);
      expect(groups.length, 1);
      expect(groups[0].dailyIncome, 80);
      expect(groups[0].dailyExpense, 0);
    });

    test('transfer outbound adds to dailyExpense', () {
      final list = [
        tx(
          id: '1',
          type: TransactionType.transfer,
          amount: 60,
          transferDirection: TransferDirection.outbound,
        ),
      ];
      final groups = groupTransactionsByDay(list);
      expect(groups.length, 1);
      expect(groups[0].dailyIncome, 0);
      expect(groups[0].dailyExpense, 60);
    });

    test('same day income + expense + transfer inbound/outbound', () {
      final list = [
        tx(id: '1', type: TransactionType.income, amount: 100),
        tx(id: '2', type: TransactionType.expense, amount: 40),
        tx(
          id: '3',
          type: TransactionType.transfer,
          amount: 30,
          transferDirection: TransferDirection.inbound,
        ),
        tx(
          id: '4',
          type: TransactionType.transfer,
          amount: 20,
          transferDirection: TransferDirection.outbound,
        ),
      ];
      final groups = groupTransactionsByDay(list);
      expect(groups.length, 1);
      expect(groups[0].dailyIncome, 100 + 30);
      expect(groups[0].dailyExpense, 40 + 20);
    });

    test('transfer without direction is not counted in daily totals', () {
      final list = [
        tx(
          id: '1',
          type: TransactionType.transfer,
          amount: 50,
          transferDirection: null,
        ),
      ];
      final groups = groupTransactionsByDay(list);
      expect(groups.length, 1);
      expect(groups[0].dailyIncome, 0);
      expect(groups[0].dailyExpense, 0);
    });
  });
}
