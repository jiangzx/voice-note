/// Status of a category budget.
enum BudgetLevel {
  /// 0-79% consumed.
  normal,

  /// 80-99% consumed.
  warning,

  /// 100%+ consumed.
  exceeded,
}

/// Budget status for a specific category in a given month.
class BudgetStatus {
  const BudgetStatus({
    required this.categoryId,
    required this.categoryName,
    required this.budgetAmount,
    required this.spentAmount,
  });

  final String categoryId;
  final String categoryName;
  final double budgetAmount;
  final double spentAmount;

  double get percentage =>
      budgetAmount > 0 ? (spentAmount / budgetAmount) * 100 : 0;

  BudgetLevel get level {
    final pct = percentage;
    if (pct >= 100) return BudgetLevel.exceeded;
    if (pct >= 80) return BudgetLevel.warning;
    return BudgetLevel.normal;
  }

  double get remaining => budgetAmount - spentAmount;
}
