/// Summary of spending/income for a single category within a time period.
class CategorySummary {
  const CategorySummary({
    required this.categoryId,
    required this.categoryName,
    required this.icon,
    required this.color,
    required this.totalAmount,
    required this.percentage,
    required this.transactionCount,
  });

  final String categoryId;
  final String categoryName;
  final String icon;
  final String color;
  final double totalAmount;

  /// Percentage of total (0.0 - 100.0).
  final double percentage;

  /// Number of transactions in this category in the period.
  final int transactionCount;
}
