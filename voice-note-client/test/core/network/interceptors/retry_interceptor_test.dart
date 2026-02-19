import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/network/interceptors/retry_interceptor.dart';

void main() {
  group('RetryInterceptor', () {
    late Dio dio;
    late int requestCount;

    setUp(() {
      requestCount = 0;
      dio = Dio(BaseOptions(baseUrl: 'https://fake.api'));
      dio.interceptors.add(
        RetryInterceptor(
          dio,
          maxRetries: 2,
          baseDelay: const Duration(milliseconds: 10),
        ),
      );

      dio.httpClientAdapter = _CountingAdapter(
        onRequest: () => requestCount++,
      );
    });

    test('does not retry on 400 client error', () async {
      dio.httpClientAdapter = _FixedResponseAdapter(
        statusCode: 400,
        body: '{"message":"bad request"}',
        onRequest: () => requestCount++,
      );

      try {
        await dio.get<dynamic>('/test');
      } on DioException {
        // expected
      }

      expect(requestCount, 1);
    });

    test('does not retry on 422 client error', () async {
      dio.httpClientAdapter = _FixedResponseAdapter(
        statusCode: 422,
        body: '{"message":"unprocessable"}',
        onRequest: () => requestCount++,
      );

      try {
        await dio.get<dynamic>('/test');
      } on DioException {
        // expected
      }

      expect(requestCount, 1);
    });

    test('does not retry on 429 rate limit', () async {
      dio.httpClientAdapter = _FixedResponseAdapter(
        statusCode: 429,
        body: '{"message":"rate limit"}',
        onRequest: () => requestCount++,
      );

      try {
        await dio.get<dynamic>('/test');
      } on DioException {
        // expected
      }

      expect(requestCount, 1);
    });

    test('retries on 500 server error up to maxRetries', () async {
      dio.httpClientAdapter = _FixedResponseAdapter(
        statusCode: 500,
        body: '{"message":"internal error"}',
        onRequest: () => requestCount++,
      );

      try {
        await dio.get<dynamic>('/test');
      } on DioException {
        // expected
      }

      // 1 original + 2 retries = 3 total
      expect(requestCount, 3);
    });

    test('retries on 502 upstream error', () async {
      dio.httpClientAdapter = _FixedResponseAdapter(
        statusCode: 502,
        body: '{"message":"bad gateway"}',
        onRequest: () => requestCount++,
      );

      try {
        await dio.get<dynamic>('/test');
      } on DioException {
        // expected
      }

      expect(requestCount, 3);
    });

    test('retries on connection timeout', () async {
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.connectionTimeout,
        onRequest: () => requestCount++,
      );

      try {
        await dio.get<dynamic>('/test');
      } on DioException {
        // expected
      }

      expect(requestCount, 3);
    });

    test('retries on connection error', () async {
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.connectionError,
        onRequest: () => requestCount++,
      );

      try {
        await dio.get<dynamic>('/test');
      } on DioException {
        // expected
      }

      expect(requestCount, 3);
    });

    test('retries on send timeout', () async {
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.sendTimeout,
        onRequest: () => requestCount++,
      );

      try {
        await dio.get<dynamic>('/test');
      } on DioException {
        // expected
      }

      expect(requestCount, 3);
    });

    test('retries on receive timeout', () async {
      dio.httpClientAdapter = _ErrorAdapter(
        type: DioExceptionType.receiveTimeout,
        onRequest: () => requestCount++,
      );

      try {
        await dio.get<dynamic>('/test');
      } on DioException {
        // expected
      }

      expect(requestCount, 3);
    });

    test('recovers from connection error then success', () async {
      var callCount = 0;
      dio.httpClientAdapter = _FunctionAdapter((options) {
        callCount++;
        requestCount++;
        if (callCount == 1) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          );
        }
        return ResponseBody.fromString('{"recovered":true}', 200);
      });

      final response = await dio.get<dynamic>('/test');

      expect(response.statusCode, 200);
      expect(requestCount, 2);
    });

    test('succeeds after transient failure', () async {
      dio.httpClientAdapter = _SequenceAdapter(
        responses: [
          _AdapterResponse(statusCode: 500, body: 'fail'),
          _AdapterResponse(statusCode: 200, body: '{"ok":true}'),
        ],
        onRequest: () {
          requestCount++;
        },
      );

      final response = await dio.get<dynamic>('/test');

      expect(response.statusCode, 200);
      expect(requestCount, 2);
    });
  });
}

// ======================== Test Adapters ========================

class _CountingAdapter implements HttpClientAdapter {
  final void Function() onRequest;
  _CountingAdapter({required this.onRequest});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest();
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterResponse {
  final int statusCode;
  final String body;
  _AdapterResponse({required this.statusCode, required this.body});
}

class _FixedResponseAdapter implements HttpClientAdapter {
  final int statusCode;
  final String body;
  final void Function() onRequest;

  _FixedResponseAdapter({
    required this.statusCode,
    required this.body,
    required this.onRequest,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest();
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
          data: body,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(body, statusCode);
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorAdapter implements HttpClientAdapter {
  final DioExceptionType type;
  final void Function() onRequest;

  _ErrorAdapter({required this.type, required this.onRequest});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest();
    throw DioException(requestOptions: options, type: type);
  }

  @override
  void close({bool force = false}) {}
}

class _FunctionAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options) handler;

  _FunctionAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _SequenceAdapter implements HttpClientAdapter {
  final List<_AdapterResponse> responses;
  final void Function() onRequest;
  int _index = 0;

  _SequenceAdapter({required this.responses, required this.onRequest});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest();
    final resp = responses[_index < responses.length ? _index : responses.length - 1];
    _index++;
    if (resp.statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: resp.statusCode,
          data: resp.body,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(resp.body, resp.statusCode);
  }

  @override
  void close({bool force = false}) {}
}
