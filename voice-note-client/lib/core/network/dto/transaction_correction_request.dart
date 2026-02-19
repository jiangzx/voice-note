import 'transaction_parse_request.dart';

/// Request body for POST /api/v1/llm/correct-transaction.
class TransactionCorrectionRequest {
  final List<BatchItem> currentBatch;
  final String correctionText;
  final ParseContext? context;

  const TransactionCorrectionRequest({
    required this.currentBatch,
    required this.correctionText,
    this.context,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'currentBatch': currentBatch.map((e) => e.toJson()).toList(),
      'correctionText': correctionText,
    };
    if (context != null) json['context'] = context!.toJson();
    return json;
  }
}

/// A single item in the correction batch context.
class BatchItem {
  final int index;
  final double? amount;
  final String? category;
  final String? type;
  final String? description;
  final String? date;

  const BatchItem({
    required this.index,
    this.amount,
    this.category,
    this.type,
    this.description,
    this.date,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'index': index,
      if (amount != null) 'amount': amount,
      if (category != null) 'category': category,
      if (type != null) 'type': type,
      if (description != null) 'description': description,
      if (date != null) 'date': date,
    };
  }
}
