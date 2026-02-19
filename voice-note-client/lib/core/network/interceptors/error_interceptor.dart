import 'dart:io';

import 'package:dio/dio.dart';

import '../api_exceptions.dart';

/// Translates Dio errors and HTTP status codes into typed [ApiException]s.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = _mapError(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
      ),
    );
  }

  ApiException _mapError(DioException err) {
    // Connection-level errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return const TimeoutException();
    }
    if (err.type == DioExceptionType.connectionError ||
        err.error is SocketException) {
      return const NetworkUnavailableException();
    }

    // HTTP status code errors
    final statusCode = err.response?.statusCode;
    final body = err.response?.data;
    final errorMsg = body is Map ? (body['message'] as String?) ?? '' : '';

    return switch (statusCode) {
      400 => ValidationException(
          message: errorMsg.isNotEmpty ? errorMsg : 'Validation failed',
          details: body is Map ? body['error'] as String? : null,
        ),
      422 => LlmParseException(errorMsg.isNotEmpty ? errorMsg : 'LLM parse failed'),
      429 => const RateLimitException(),
      502 => const UpstreamException(),
      _ => ServerException(statusCode ?? 0, errorMsg.isNotEmpty ? errorMsg : 'Server error'),
    };
  }
}
