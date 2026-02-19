/// Unified parse result from either local NLP engine or server LLM.
class ParseResult {
  final double? amount;
  final String? date;
  final String? category;
  final String? description;
  final String type;
  final String? account;
  final double confidence;
  final ParseSource source;

  const ParseResult({
    this.amount,
    this.date,
    this.category,
    this.description,
    this.type = 'EXPENSE',
    this.account,
    this.confidence = 0.0,
    required this.source,
  });

  /// Whether all required fields are present (amount + category).
  bool get isComplete => amount != null && category != null;

  /// Create a copy with updated fields (for corrections).
  ParseResult copyWith({
    double? amount,
    String? date,
    String? category,
    String? description,
    String? type,
    String? account,
  }) {
    return ParseResult(
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      description: description ?? this.description,
      type: type ?? this.type,
      account: account ?? this.account,
      confidence: confidence,
      source: source,
    );
  }
}

/// Where the parse result came from.
enum ParseSource { local, llm }
