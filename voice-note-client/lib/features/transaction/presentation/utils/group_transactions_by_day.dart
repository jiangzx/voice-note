import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/transaction_filter.dart';

/// Groups a list of transactions (ordered by date desc) by day and computes
/// daily income/expense subtotals. Used for timeline display on home and lists.
List<DailyTransactionGroup> groupTransactionsByDay(
  List<TransactionEntity> transactions,
) {
  if (transactions.isEmpty) return [];

  final grouped = <DateTime, List<TransactionEntity>>{};
  for (final tx in transactions) {
    final dayKey = DateTime(tx.date.year, tx.date.month, tx.date.day);
    grouped.putIfAbsent(dayKey, () => []).add(tx);
  }

  final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return sortedKeys.map((day) {
    final txs = grouped[day]!;
    var income = 0.0;
    var expense = 0.0;
    for (final tx in txs) {
      if (tx.type == TransactionType.income) income += tx.amount;
      if (tx.type == TransactionType.expense) expense += tx.amount;
    }
    return DailyTransactionGroup(
      date: day,
      dailyIncome: income,
      dailyExpense: expense,
      transactions: txs,
    );
  }).toList();
}
