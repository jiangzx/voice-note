import 'dart:developer' as dev;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Logs HTTP requests and responses in debug mode only.
class LoggingInterceptor extends Interceptor {
  static const _ridHeader = 'X-Request-ID';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final rid = options.headers[_ridHeader] ?? '';
      dev.log('→ ${options.method} ${options.uri} [$rid]', name: 'HTTP');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final rid = response.requestOptions.headers[_ridHeader] ?? '';
      dev.log(
        '← ${response.statusCode} ${response.requestOptions.uri} [$rid]',
        name: 'HTTP',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final rid = err.requestOptions.headers[_ridHeader] ?? '';
      dev.log(
        '✖ ${err.response?.statusCode ?? 'N/A'} ${err.requestOptions.uri} [$rid] — ${err.message}',
        name: 'HTTP',
      );
    }
    handler.next(err);
  }
}
