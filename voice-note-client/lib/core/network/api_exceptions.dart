/// Base class for all API errors.
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Network is unreachable (no internet, DNS failure, etc.).
class NetworkUnavailableException extends ApiException {
  const NetworkUnavailableException([super.message = 'Network unavailable']);
}

/// Server returned HTTP 429 Too Many Requests.
class RateLimitException extends ApiException {
  const RateLimitException([super.message = 'Rate limit exceeded']);
}

/// Server returned HTTP 422 — LLM could not parse the input.
class LlmParseException extends ApiException {
  const LlmParseException([super.message = 'LLM parse failed']);
}

/// Server returned an upstream error (502).
class UpstreamException extends ApiException {
  const UpstreamException([super.message = 'Upstream service error']);
}

/// Server returned a validation error (400).
class ValidationException extends ApiException {
  final String? details;
  const ValidationException({String message = 'Validation failed', this.details})
      : super(message);
}

/// Generic server error for unhandled status codes.
class ServerException extends ApiException {
  final int statusCode;
  const ServerException(this.statusCode, [super.message = 'Server error']);
}

/// Request timed out.
class TimeoutException extends ApiException {
  const TimeoutException([super.message = 'Request timed out']);
}
