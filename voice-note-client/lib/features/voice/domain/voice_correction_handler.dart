import 'parse_result.dart';
import '../data/nlp/amount_extractor.dart';
import '../data/nlp/category_matcher.dart';

/// Identifies correction intents from user speech and applies field updates.
class VoiceCorrectionHandler {
  static const _cancelKeywords = ['不要了', '取消', '删掉', '算了', '不记了'];
  static const _correctionPrefixes = [
    '不对', '改一下', '改成', '错了',
    '修改为', '改为', '应该是', '不是', '搞错了', '弄错了',
  ];
  static const _fieldKeywords = ['金额', '分类', '日期', '收入', '支出'];

  static final _indexedConfirmPattern = RegExp(r'确认第(\d+)笔');
  static final _indexedCancelPattern = RegExp(r'(?:删掉|取消|去掉)第(\d+)笔');

  /// Determine the type of user intent from [text].
  CorrectionIntent classify(String text) {
    // Indexed confirm/cancel (highest specificity)
    final indexedConfirm = _indexedConfirmPattern.firstMatch(text);
    if (indexedConfirm != null) {
      return CorrectionIntent.confirmItem;
    }
    final indexedCancel = _indexedCancelPattern.firstMatch(text);
    if (indexedCancel != null) {
      return CorrectionIntent.cancelItem;
    }

    // Cancel intent
    for (final kw in _cancelKeywords) {
      if (text.contains(kw)) return CorrectionIntent.cancel;
    }

    // Correction intent (before confirmation — "不对" must beat "对")
    for (final prefix in _correctionPrefixes) {
      if (text.contains(prefix)) return CorrectionIntent.correction;
    }
    for (final kw in _fieldKeywords) {
      if (text.contains(kw)) return CorrectionIntent.correction;
    }

    // Exit intent
    if (_isExit(text)) return CorrectionIntent.exit;

    // Continue intent
    if (_isContinue(text)) return CorrectionIntent.continueRecording;

    // Confirm intent (after correction to avoid "不对" false positive)
    if (_isConfirmation(text)) return CorrectionIntent.confirm;

    // Default: treat as new input
    return CorrectionIntent.newInput;
  }

  /// Extract 1-based item index from indexed intent text.
  /// Returns null if no index pattern found.
  int? extractItemIndex(String text) {
    final confirm = _indexedConfirmPattern.firstMatch(text);
    if (confirm != null) return int.tryParse(confirm.group(1)!);
    final cancel = _indexedCancelPattern.firstMatch(text);
    if (cancel != null) return int.tryParse(cancel.group(1)!);
    return null;
  }

  /// Apply a correction [text] to an existing [result].
  /// Returns updated ParseResult, or null if correction could not be determined.
  ParseResult? applyCorrection(String text, ParseResult current) {
    // Transaction type correction (收入/支出)
    final typeResult = _applyTypeCorrection(text, current);
    if (typeResult != null) return typeResult;

    // Amount correction
    final newAmount = AmountExtractor.extract(text);
    if (newAmount != null) {
      return current.copyWith(amount: newAmount);
    }

    // Category correction
    final matcher = CategoryMatcher();
    final newCategory = matcher.match(text);
    if (newCategory != null) {
      return current.copyWith(category: newCategory);
    }

    return null;
  }

  ParseResult? _applyTypeCorrection(String text, ParseResult current) {
    if (text.contains('收入') && current.type != 'INCOME') {
      return current.copyWith(type: 'INCOME');
    }
    if (text.contains('支出') && current.type != 'EXPENSE') {
      return current.copyWith(type: 'EXPENSE');
    }
    return null;
  }

  bool _isConfirmation(String text) {
    const keywords = ['对的', '对', '确认', '嗯对', '没错', '是的', '好的', '可以', '确定'];
    return keywords.any((kw) => text.trim() == kw || text.contains(kw));
  }

  bool _isContinue(String text) {
    const keywords = ['还有', '继续', '再记'];
    return keywords.any((kw) => text.contains(kw));
  }

  bool _isExit(String text) {
    const keywords = ['没了', '拜拜', '退出', '不用了', '结束'];
    return keywords.any((kw) => text.contains(kw));
  }
}

/// Types of user intent during the confirmation phase.
enum CorrectionIntent {
  /// User confirms the current transaction (all items).
  confirm,

  /// User confirms a specific item by index.
  confirmItem,

  /// User wants to cancel the current transaction (all items).
  cancel,

  /// User wants to cancel a specific item by index.
  cancelItem,

  /// User wants to correct a field.
  correction,

  /// User wants to continue recording more transactions.
  continueRecording,

  /// User wants to exit the voice session.
  exit,

  /// Text is a new transaction input (not a correction).
  newInput,
}
