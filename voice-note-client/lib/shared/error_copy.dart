/// Centralized, user-facing error copy. Friendly and slightly witty; no error codes.
/// Used for consistent UX and future i18n. Codes are logged, not shown.
abstract final class ErrorCopy {
  ErrorCopy._();

  // --- ASR / 语音 ---
  static const String asrTimeout =
      '语音服务打了个小盹，检查下网络再试一次吧';
  static const String asrNetwork =
      '网络好像开小差了，连上后再来试试';
  static const String asrRateLimit =
      '操作有点频繁啦，歇几秒再试';
  static const String asrUnavailable =
      '语音服务暂时不在线，稍后再试';
  static const String asrStartFailed =
      '语音没准备好，稍后再试一次';
  static const String asrNoResult =
      '语音没识别到结果，检查下网络或试试键盘输入';

  // --- 录音 / 权限 ---
  static const String recordNoPermission =
      '需要麦克风权限才能记账哦，去设置里开一下';
  static const String recordBusy =
      '麦克风可能被占用了，关掉其他录音应用再试';
  static const String recordStartFailed =
      '录音没启动成功，检查下权限或重试';

  // --- LLM / 语义解析 ---
  static const String llmTimeout =
      '理解你的话时超时了，网络好的时候再试';
  static const String llmNetwork =
      '网络不稳，没解析成，连上后再试';
  static const String llmRateLimit =
      '请求太勤啦，稍等几秒再试';
  static const String llmUnavailable =
      '语义解析暂时休息中，稍后再试';
  static const String llmParseFailed =
      '这句没解析成功，换个说法试试';

  // --- 通用 / 表单 ---
  static const String saveFailed = '没保存成功，再试一次吧';
  static const String deleteFailed = '删除没成功，请重试';
  static const String loadFailed = '加载没成功，点一下重试';
  static const String notAvailableYet = '该功能暂未开放';
  static const String amountRequired = '先填一下金额哦';
  static const String categoryRequired = '先选一下分类哦';
  /// 通用兜底：TTS/原生错误等
  static const String retryLater = '出了点小状况，稍后再试一下';
  static const String asrReconnectFailed = '语音连接断了，重连没成功，再试一次吧';
}
