import 'transaction_parse_response.dart';

/// Response from POST /api/v1/llm/parse-transaction (batch format).
/// Wraps one or more parsed transactions from a single voice input.
class TransactionBatchParseResponse {
  final List<TransactionParseResponse> transactions;
  final String model;

  const TransactionBatchParseResponse({
    required this.transactions,
    required this.model,
  });

  factory TransactionBatchParseResponse.fromJson(Map<String, dynamic> json) {
    final list = json['transactions'] as List<dynamic>? ?? [];
    return TransactionBatchParseResponse(
      transactions: list
          .map((e) =>
              TransactionParseResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      model: json['model'] as String? ?? '',
    );
  }
}
