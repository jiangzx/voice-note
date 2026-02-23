import '../../../transaction/domain/entities/transaction_entity.dart';

/// Calculates the book balance for an account.
///
/// Formula: initial_balance + income + transfer_in - expense - transfer_out
/// Only non-draft transactions are counted.
class CalculateBalanceUseCase {
  const CalculateBalanceUseCase();

  double call({
    required double initialBalance,
    required List<TransactionEntity> transactions,
  }) {
    var balance = initialBalance;

    for (final t in transactions) {
      if (t.isDraft) continue;

      switch (t.type) {
        case TransactionType.income:
          balance += t.amount;
          break;
        case TransactionType.expense:
          balance -= t.amount;
          break;
        case TransactionType.transfer:
          if (t.transferDirection == TransferDirection.inbound) {
            balance += t.amount;
          } else if (t.transferDirection == TransferDirection.outbound) {
            balance -= t.amount;
          }
          break;
      }
    }

    return balance;
  }
}
