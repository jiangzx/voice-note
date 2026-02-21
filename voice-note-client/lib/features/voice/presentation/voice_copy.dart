/// Centralized copy for voice recording screen and session feedback.
/// Used for UX consistency and future i18n.
abstract final class VoiceCopy {
  VoiceCopy._();

  // --- Main area (core visual) ---
  static const String mainReadyTitle = '对着我说话，就能一键记账';
  static const String mainReadySubtitle =
      '试试说：午饭花了30元 / 工资到账8000元';
  static const String mainListening = '我在听，你慢慢说～';
  static const String mainProcessing = '正在帮你记录账单...';
  static const String mainConfirmSingle = '请确认以下信息';
  static const String mainConfirmBatch = '请确认或说出要修改的内容';

  // --- Timeout ---
  static const String timeoutWarningMain =
      '还在吗？暂时不用的话我会先休息哦';
  static const String timeoutWarningSub = '30秒后自动退出';

  // --- Hints ---
  static const String idleHint = '点击开始';
  static const String pushToTalkHint = '按住 说话';

  // --- Recognition loading ---
  static const String recognizingHint = '正在识别语音，请稍候...';
  static const String recognizingTimeout = '识别超时，请重试';

  // --- Dialogue feedback ---
  static const String feedbackCancel =
      '已为你取消本次记录，你可以继续说话记账啦';
  static const String feedbackNoBill =
      '没听清你的账单哦，试试说"买咖啡花了20元"这类句式吧';

  // --- Example phrases (clickable chips) ---
  static const String examplePhrase1 = '午饭花了30元';
  static const String examplePhrase2 = '工资到账8000元';

  /// Success template: 已帮你记录：{{category}} {{typeLabel}}{{amount}}元
  static String successFeedback({
    required String? category,
    required String typeLabel,
    required String amountStr,
  }) {
    final cat = category ?? '';
    return '已帮你记录：$cat $typeLabel$amountStr元';
  }
}
