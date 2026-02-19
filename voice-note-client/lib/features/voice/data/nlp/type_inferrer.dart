/// Infers transaction type (expense/income/transfer) from text keywords.
class TypeInferrer {
  static const _incomeKeywords = [
    '工资', '薪水', '发工资', '收入', '收到', '进账', '入账',
    '奖金', '年终奖', '兼职', '副业', '收红包', '退款',
  ];

  static const _transferKeywords = [
    '转账', '转给', '转到', '转入', '转出', '还钱', '还款',
  ];

  static const _expenseKeywords = [
    '花了', '花', '付了', '付', '消费', '买了', '买', '充值',
    '缴费', '交了', '支付',
  ];

  /// Infer transaction type from [text].
  /// Returns 'EXPENSE', 'INCOME', or 'TRANSFER'. Defaults to 'EXPENSE'.
  static String infer(String text) {
    // Check income first (more specific)
    for (final kw in _incomeKeywords) {
      if (text.contains(kw)) return 'INCOME';
    }

    // Then transfer
    for (final kw in _transferKeywords) {
      if (text.contains(kw)) return 'TRANSFER';
    }

    // Expense is default
    return 'EXPENSE';
  }
}
