/// 单笔排行项：选定时间范围内按金额排序的单笔交易。
class TopTransactionRankItem {
  const TopTransactionRankItem({
    required this.id,
    required this.amount,
    this.description,
    required this.categoryName,
    required this.icon,
    required this.color,
  });

  final String id;
  final double amount;
  final String? description;
  final String categoryName;
  final String icon;
  final String color;
}
