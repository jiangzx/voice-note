import '../../../core/network/api_client.dart';
import '../../../core/network/dto/transaction_batch_parse_response.dart';
import '../../../core/network/dto/transaction_correction_request.dart';
import '../../../core/network/dto/transaction_correction_response.dart';
import '../../../core/network/dto/transaction_parse_request.dart';
import '../domain/parse_result.dart';

/// Handles LLM-based transaction parsing and correction via the server.
class LlmRepository {
  final ApiClient _apiClient;

  LlmRepository(this._apiClient);

  /// Parse natural language text into structured transactions (batch).
  /// Returns one or more [ParseResult]s mapped from the server response.
  Future<List<ParseResult>> parseTransaction({
    required String text,
    List<String>? recentCategories,
    List<String>? customCategories,
    List<String>? accounts,
  }) async {
    final request = TransactionParseRequest(
      text: text,
      context: (recentCategories != null ||
              customCategories != null ||
              accounts != null)
          ? ParseContext(
              recentCategories: recentCategories,
              customCategories: customCategories,
              accounts: accounts,
            )
          : null,
    );

    try {
      final json = await _apiClient.post(
        '/api/v1/llm/parse-transaction',
        data: request.toJson(),
      );
      final batch = TransactionBatchParseResponse.fromJson(json);
      return batch.transactions
          .map((t) => ParseResult(
          amount: t.amount,
          date: t.date,
          category: t.category,
          description: t.description,
          type: t.type ?? 'EXPENSE',
          account: t.account,
          transferDirection: t.transferDirection,
          counterparty: t.counterparty,
          confidence: t.confidence,
          source: ParseSource.llm,
        ))
          .toList();
    } on LlmParseException {
      rethrow;
    } catch (e) {
      throw LlmParseException('LLM parsing failed: $e');
    }
  }

  /// Send current batch + correction text to the LLM for dialogue-style
  /// correction. Returns the raw [TransactionCorrectionResponse].
  Future<TransactionCorrectionResponse> correctTransaction({
    required List<BatchItem> currentBatch,
    required String correctionText,
    List<String>? recentCategories,
    List<String>? customCategories,
  }) async {
    final request = TransactionCorrectionRequest(
      currentBatch: currentBatch,
      correctionText: correctionText,
      context: (recentCategories != null || customCategories != null)
          ? ParseContext(
              recentCategories: recentCategories,
              customCategories: customCategories,
            )
          : null,
    );

    try {
      final json = await _apiClient.post(
        '/api/v1/llm/correct-transaction',
        data: request.toJson(),
      );
      return TransactionCorrectionResponse.fromJson(json);
    } on LlmParseException {
      rethrow;
    } catch (e) {
      throw LlmParseException('LLM correction failed: $e');
    }
  }
}

/// Thrown when LLM transaction parsing fails.
class LlmParseException implements Exception {
  final String message;
  const LlmParseException(this.message);

  @override
  String toString() => 'LlmParseException: $message';
}
