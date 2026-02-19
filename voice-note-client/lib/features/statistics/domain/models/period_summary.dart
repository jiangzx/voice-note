/// Aggregated income/expense for a time period.
class PeriodSummary {
  const PeriodSummary({
    required this.totalIncome,
    required this.totalExpense,
  });

  final double totalIncome;
  final double totalExpense;

  double get balance => totalIncome - totalExpense;
}
