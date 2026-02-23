/// Centralized copy for voice recording screen and session feedback.
/// Used for UX consistency and future i18n.
abstract final class VoiceCopy {
  VoiceCopy._();

  // --- Main area (core visual) ---
  static const String mainReadyTitle = '对着我说话，就能一键记账';
  static const String mainReadySubtitle = '试试说：午饭花了30元 / 工资到账8000元';
  static const String mainListening = '我在听，你慢慢说～';
  static const String mainProcessing = '正在帮你记录账单...';
  static const String mainConfirmSingle = '请确认以下信息';
  static const String mainConfirmBatch = '请确认或说出要修改的内容';

  // --- Timeout ---
  static const String timeoutWarningMain = '还在吗？暂时不用的话我会先休息哦';
  static const String timeoutWarningSub = '30秒后自动退出';

  // --- Hints ---
  static const String idleHint = '点击开始';
  static const String pushToTalkHint = '按住 说话';
  /// Shown while holding and in send zone: release to send.
  static const String pushToTalkReleaseToSend = '松开 发送';
  /// Shown while holding and in cancel zone (slid up): release to cancel.
  static const String pushToTalkReleaseToCancel = '松开 取消';
  /// Hint above button: slide up to cancel (WeChat-style).
  static const String pushToTalkSlideUpToCancel = '上滑取消';
  /// Shown when user releases after very short hold (WeChat-style).
  static const String pushToTalkTooShort = '说话时间太短';

  // --- Mode-specific hints (manual / keyboard / auto) ---
  static const String modeHintManual = '按住说话，一次记多笔更省心';
  static const String modeHintKeyboard = '输入账单，一次记多笔更省心';
  static const String modeHintAuto = '自动识别语音，轻松记一笔';
  static const String modeSwitchHintManual = '已切换到手动模式，支持一次性记录多笔哦';
  static const String modeSwitchHintKeyboard = '已切换到键盘模式，支持一次性记录多笔哦';
  static const String autoModeMultiNotSupported = '自动模式暂不支持多笔，切换到手动模式试试吧';

  /// Shown after user switches from auto to manual from the multi-batch banner (current batch is cleared).
  static const String autoModeSwitchBatchCleared = '已切换到手动模式，当前多笔已清空，请重新说话记录';

  /// Substring to emphasize in manual/keyboard empty state and hints.
  static const String emptyStateHighlight = '一次记多笔';

  /// Example for manual/keyboard "multi-entry" hint.
  static const String modeExampleMulti = '早餐 15 元；公交 2 元；咖啡 30 元';

  /// Full line for UI: "例如：" + [modeExampleMulti]. Single source for label + content.
  static String get modeExampleMultiWithLabel => '例如：$modeExampleMulti';

  // --- Recognition loading ---
  static const String recognizingHint = '正在识别语音，请稍候...';
  static const String recognizingTimeout = '识别超时，请重试';

  // --- Dialogue feedback ---
  static const String feedbackCancel = '已为你取消本次记录，你可以继续说话记账啦';
  static const String feedbackNoBill = '没听清你的账单哦，试试说"买咖啡花了20元"这类句式吧';

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
