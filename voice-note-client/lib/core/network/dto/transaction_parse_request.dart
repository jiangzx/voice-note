/// Request body for POST /api/v1/llm/parse-transaction.
class TransactionParseRequest {
  final String text;
  final ParseContext? context;

  const TransactionParseRequest({
    required this.text,
    this.context,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{'text': text};
    if (context != null) json['context'] = context!.toJson();
    return json;
  }
}

/// Optional context to improve LLM parsing accuracy.
class ParseContext {
  final List<String>? recentCategories;
  final List<String>? customCategories;
  final List<String>? accounts;

  const ParseContext({
    this.recentCategories,
    this.customCategories,
    this.accounts,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (recentCategories != null) json['recentCategories'] = recentCategories;
    if (customCategories != null) json['customCategories'] = customCategories;
    if (accounts != null) json['accounts'] = accounts;
    return json;
  }
}
