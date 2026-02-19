import 'dart:math';

import 'package:dio/dio.dart';

/// Attaches a unique X-Request-ID header to every outgoing request
/// for end-to-end request tracing with the server.
class RequestIdInterceptor extends Interceptor {
  static const _headerName = 'X-Request-ID';
  static final _random = Random.secure();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[_headerName] = _generateId();
    handler.next(options);
  }

  static String _generateId() {
    return _random.nextInt(0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  }
}
