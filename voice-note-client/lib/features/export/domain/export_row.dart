/// Flat DTO for a single export row, decoupled from database entities.
class ExportRow {
  final String date;       // yyyy-MM-dd
  final String time;       // HH:mm
  final String type;       // 支出 / 收入 / 转账
  final String category;   // category name
  final double amount;     // positive value
  final String account;    // account name
  final String note;       // description or empty

  const ExportRow({
    required this.date,
    required this.time,
    required this.type,
    required this.category,
    required this.amount,
    required this.account,
    this.note = '',
  });

  /// Column headers in Chinese.
  static const List<String> headers = [
    '日期',
    '时间',
    '类型',
    '分类',
    '金额',
    '账户',
    '备注',
  ];

  List<String> toList() => [date, time, type, category, amount.toStringAsFixed(2), account, note];
}
