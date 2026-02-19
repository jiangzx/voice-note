/// Response from POST /api/v1/asr/token.
class AsrTokenResponse {
  final String token;
  final int expiresAt;
  final String model;
  final String wsUrl;

  const AsrTokenResponse({
    required this.token,
    required this.expiresAt,
    required this.model,
    required this.wsUrl,
  });

  factory AsrTokenResponse.fromJson(Map<String, dynamic> json) {
    return AsrTokenResponse(
      token: json['token'] as String,
      expiresAt: json['expiresAt'] as int,
      model: json['model'] as String,
      wsUrl: json['wsUrl'] as String,
    );
  }

  /// Whether this token is still valid (with a 30s safety margin).
  bool get isValid {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt - now > 30;
  }
}
