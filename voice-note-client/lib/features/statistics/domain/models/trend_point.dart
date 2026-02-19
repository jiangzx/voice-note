/// A single data point in a time series trend chart.
class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.income,
    required this.expense,
  });

  /// The date label (e.g., "2026-02-15" or "2026-02").
  final String date;
  final double income;
  final double expense;
}
