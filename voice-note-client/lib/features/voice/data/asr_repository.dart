import '../../../core/network/api_client.dart';
import '../../../core/network/dto/asr_token_response.dart';

/// Manages ASR token lifecycle — fetches from server, caches, and refreshes.
class AsrRepository {
  final ApiClient _apiClient;
  AsrTokenResponse? _cachedToken;

  AsrRepository(this._apiClient);

  /// Get a valid ASR token. Returns cached token if still valid,
  /// otherwise fetches a new one from the server.
  Future<AsrTokenResponse> getToken({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedToken != null && _cachedToken!.isValid) {
      return _cachedToken!;
    }

    try {
      final json = await _apiClient.post('/api/v1/asr/token');
      final token = AsrTokenResponse.fromJson(json);
      if (token.token.isEmpty || token.wsUrl.isEmpty) {
        throw const AsrTokenException('Invalid token response: empty token or URL');
      }
      _cachedToken = token;
      return token;
    } on AsrTokenException {
      rethrow;
    } catch (e) {
      throw AsrTokenException('Failed to fetch ASR token: $e');
    }
  }

  /// Invalidate the cached token (e.g., after a WebSocket auth failure).
  void invalidateToken() {
    _cachedToken = null;
  }

  /// Whether a valid cached token exists.
  bool get hasValidToken => _cachedToken != null && _cachedToken!.isValid;
}

/// Thrown when ASR token acquisition fails.
class AsrTokenException implements Exception {
  final String message;
  const AsrTokenException(this.message);

  @override
  String toString() => 'AsrTokenException: $message';
}
