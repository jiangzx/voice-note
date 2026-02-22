/// Response from POST /api/v1/llm/parse-transaction.
class TransactionParseResponse {
  final double? amount;
  final String currency;
  final String? date;
  final String? category;
  final String? description;
  final String? type;
  final String? account;
  final String? transferDirection;
  final String? counterparty;
  final double confidence;
  final String model;

  const TransactionParseResponse({
    this.amount,
    this.currency = 'CNY',
    this.date,
    this.category,
    this.description,
    this.type,
    this.account,
    this.transferDirection,
    this.counterparty,
    required this.confidence,
    required this.model,
  });

  factory TransactionParseResponse.fromJson(Map<String, dynamic> json) {
    return TransactionParseResponse(
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'CNY',
      date: json['date'] as String?,
      category: json['category'] as String?,
      description: json['description'] as String?,
      type: json['type'] as String?,
      account: json['account'] as String?,
      transferDirection: json['transfer_direction'] as String?,
      counterparty: json['counterparty'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      model: json['model']?.toString() ?? '',
    );
  }

  /// Whether all required fields for a transaction are present.
  bool get isComplete => amount != null && category != null;
}
