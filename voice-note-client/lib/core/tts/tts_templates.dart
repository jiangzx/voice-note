/// Predefined TTS speech templates with dynamic parameter interpolation.
class TtsTemplates {
  const TtsTemplates._();

  static String welcome() => '你好，想记点什么？';

  static String confirm({
    String? category,
    required String type,
    required double amount,
  }) {
    final typeLabel = _typeLabel(type);
    final amountStr = _formatAmount(amount);
    final catPart = category ?? '';
    return '识别到$catPart$typeLabel$amountStr元，确认吗？';
  }

  static String saved() => '记好了，还有吗？';

  static String timeout() => '还在吗？30秒后我就先走啦';

  static String sessionEnd({required int count, required double total}) {
    return '本次记了$count笔，共${_formatAmount(total)}元，拜拜';
  }

  // ── Correction templates ──

  static String correctionLoading() => '好的，正在修改';

  static String correctionConfirm() => '已修改，请确认';

  static String correctionFailed() => '没听清要改什么，请再说一次';

  // ── Batch templates ──

  /// Per-item announcement for small batches (2–5 items).
  static String batchConfirmation(List<({String? category, String type, double? amount})> items) {
    final buf = StringBuffer('识别到${items.length}笔交易：');
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      final cat = it.category ?? '';
      final typeLabel = _typeLabel(it.type);
      final amt = it.amount != null ? '${_formatAmount(it.amount!)}元' : '';
      buf.write('第${i + 1}笔，$cat$typeLabel$amt');
      buf.write(i < items.length - 1 ? '；' : '。');
    }
    buf.write('确认吗？');
    return buf.toString();
  }

  /// Summary announcement for larger batches (6+ items).
  static String batchSummary({required int count, required double total}) {
    return '识别到$count笔交易，合计${_formatAmount(total)}元，请逐笔确认';
  }

  static String batchSaved({required int count}) => '已保存$count笔交易';

  static String batchItemCancelled({required int displayIndex}) =>
      '第$displayIndex笔已取消';

  static String batchTargetedCorrection({required int displayIndex}) =>
      '第$displayIndex笔已修改';

  static String batchAppended({required int displayIndex}) =>
      '好的，已追加第$displayIndex笔';

  static String batchLimitReached() => '最多只能记10笔，请先确认当前交易';

  // ── Helpers ──

  static String _typeLabel(String type) => switch (type.toLowerCase()) {
        'expense' => '支出',
        'income' => '收入',
        'transfer' => '转账',
        _ => '支出',
      };

  static String _formatAmount(double amount) => amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);
}
