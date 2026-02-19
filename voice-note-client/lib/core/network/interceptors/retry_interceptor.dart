import 'dart:developer' as dev;
import 'dart:math';

import 'package:dio/dio.dart';

/// Retries failed requests with exponential backoff for transient errors.
///
/// Retries on: connection errors, timeouts, 5xx server errors.
/// Does NOT retry on: 4xx client errors (400, 422, 429).
class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  static const _retryCountKey = 'retry_count';

  RetryInterceptor(
    this._dio, {
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
  });

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final retryCount =
        (err.requestOptions.extra[_retryCountKey] as int?) ?? 0;
    if (retryCount >= maxRetries) {
      return handler.next(err);
    }

    final delay = baseDelay * pow(2, retryCount).toInt();
    dev.log(
      'Retry ${retryCount + 1}/$maxRetries after ${delay.inMilliseconds}ms: '
      '${err.requestOptions.path}',
      name: 'RetryInterceptor',
    );

    await Future<void>.delayed(delay);

    err.requestOptions.extra[_retryCountKey] = retryCount + 1;

    try {
      final response = await _dio.fetch<dynamic>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (e, stackTrace) {
      handler.next(DioException(
        requestOptions: err.requestOptions,
        error: e,
        stackTrace: stackTrace,
      ));
    }
  }

  bool _shouldRetry(DioException err) {
    // Retry connection-level errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry 5xx server errors (upstream failures, etc.)
    final status = err.response?.statusCode;
    if (status != null && status >= 500) {
      return true;
    }

    return false;
  }
}
