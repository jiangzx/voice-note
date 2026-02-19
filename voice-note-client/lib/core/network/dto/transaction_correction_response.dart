/// Response from POST /api/v1/llm/correct-transaction.
class TransactionCorrectionResponse {
  final List<CorrectionItem> corrections;
  final CorrectionIntent intent;
  final double confidence;
  final String model;

  const TransactionCorrectionResponse({
    required this.corrections,
    required this.intent,
    required this.confidence,
    required this.model,
  });

  factory TransactionCorrectionResponse.fromJson(Map<String, dynamic> json) {
    final list = json['corrections'] as List<dynamic>? ?? [];
    return TransactionCorrectionResponse(
      corrections: list
          .map((e) => CorrectionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      intent: CorrectionIntent.fromValue(json['intent'] as String? ?? ''),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      model: json['model'] as String? ?? '',
    );
  }
}

/// Field-level delta for a single batch item.
class CorrectionItem {
  final int index;
  final Map<String, dynamic> updatedFields;

  const CorrectionItem({
    required this.index,
    this.updatedFields = const {},
  });

  factory CorrectionItem.fromJson(Map<String, dynamic> json) {
    return CorrectionItem(
      index: json['index'] as int? ?? 0,
      updatedFields:
          Map<String, dynamic>.from(json['updatedFields'] as Map? ?? {}),
    );
  }
}

/// Secondary intent classification from the LLM correction service.
enum CorrectionIntent {
  correction,
  confirm,
  cancel,
  unclear,
  append;

  static CorrectionIntent fromValue(String value) {
    return CorrectionIntent.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => CorrectionIntent.unclear,
    );
  }
}
