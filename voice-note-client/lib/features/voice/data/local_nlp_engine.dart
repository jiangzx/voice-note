import 'package:intl/intl.dart';

import 'nlp/amount_extractor.dart';
import 'nlp/category_matcher.dart';
import 'nlp/date_extractor.dart';
import 'nlp/type_inferrer.dart';

/// Result of local NLP parsing attempt.
class LocalParseResult {
  final double? amount;
  final String? date;
  final String? category;
  final String? description;
  final String type;
  final bool isComplete;

  const LocalParseResult({
    this.amount,
    this.date,
    this.category,
    this.description,
    required this.type,
    required this.isComplete,
  });
}

/// Orchestrates local NLP extractors to parse natural language into
/// structured transaction data. Runs entirely on-device with zero
/// network cost.
class LocalNlpEngine {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  final CategoryMatcher _categoryMatcher;

  LocalNlpEngine({List<String>? customCategories})
      : _categoryMatcher = CategoryMatcher(customCategories: customCategories);

  /// Max input length accepted for local parsing.
  static const int maxInputLength = 200;

  /// Parse [text] into structured transaction fields.
  /// Returns a [LocalParseResult] indicating what was extracted.
  LocalParseResult parse(String text, {DateTime? now}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const LocalParseResult(type: 'EXPENSE', isComplete: false);
    }

    // Truncate excessively long input to prevent regex performance issues
    final input = trimmed.length > maxInputLength
        ? trimmed.substring(0, maxInputLength)
        : trimmed;

    final amount = AmountExtractor.extract(input);
    final dateTime = DateExtractor.extract(input, now: now);
    final date = dateTime != null ? _dateFormat.format(dateTime) : null;
    final category = _categoryMatcher.match(input);
    final type = TypeInferrer.infer(input);

    // Build description from text (strip numbers and common filler words)
    final description = _extractDescription(text, category);

    // Consider parse complete if at least amount + category are present
    final isComplete = amount != null && category != null;

    return LocalParseResult(
      amount: amount,
      date: date,
      category: category,
      description: description,
      type: type,
      isComplete: isComplete,
    );
  }

  /// Derive a brief description from the raw text.
  String? _extractDescription(String text, String? category) {
    // If category was matched, use the matched keyword as description
    if (category != null) {
      // Find the keyword that matched this category
      final cleaned = text
          .replaceAll(RegExp(r'[\d.]+'), '')
          .replaceAll(RegExp(r'[零一二三四五六七八九十百千万亿两]+\s*(?:块钱?|元|圆)'), '')
          .replaceAll(RegExp(r'[¥￥元块钱圆]'), '')
          .replaceAll(RegExp(r'花了?|付了?|消费了?|收到?|今天|昨天|前天'), '')
          .trim();
      return cleaned.isNotEmpty ? cleaned : null;
    }
    return text.length <= 20 ? text : null;
  }
}
