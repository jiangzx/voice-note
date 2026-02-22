/// One row in the bill summary table: one day's 支出、收入、结余.
class DailyBreakdownRow {
  const DailyBreakdownRow({
    required this.dateLabel,
    required this.income,
    required this.expense,
  });

  final String dateLabel;
  final double income;
  final double expense;

  double get balance => income - expense;
}
