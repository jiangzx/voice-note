import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/network/api_client.dart';
import 'package:suikouji/core/network/api_config.dart';
import 'package:suikouji/core/network/dto/asr_token_response.dart';
import 'package:suikouji/core/network/dto/transaction_parse_request.dart';
import 'package:suikouji/core/network/dto/transaction_parse_response.dart';

void main() {
  group('AsrTokenResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'token': 'st-test-token',
        'expiresAt': 1740000000,
        'model': 'qwen3-asr-flash-realtime',
        'wsUrl': 'wss://dashscope.aliyuncs.com/api/v1/services/asr/ws',
      };

      final response = AsrTokenResponse.fromJson(json);

      expect(response.token, 'st-test-token');
      expect(response.expiresAt, 1740000000);
      expect(response.model, 'qwen3-asr-flash-realtime');
      expect(response.wsUrl, contains('asr/ws'));
    });

    test('isValid returns false for expired token', () {
      const response = AsrTokenResponse(
        token: 'st-expired',
        expiresAt: 0,
        model: 'test',
        wsUrl: 'wss://test',
      );

      expect(response.isValid, isFalse);
    });

    test('isValid returns true for future token', () {
      final futureTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300;
      final response = AsrTokenResponse(
        token: 'st-valid',
        expiresAt: futureTimestamp,
        model: 'test',
        wsUrl: 'wss://test',
      );

      expect(response.isValid, isTrue);
    });
  });

  group('TransactionParseRequest', () {
    test('toJson with text only', () {
      const request = TransactionParseRequest(text: '午饭35');
      final json = request.toJson();

      expect(json['text'], '午饭35');
      expect(json.containsKey('context'), isFalse);
    });

    test('toJson with context', () {
      const request = TransactionParseRequest(
        text: '午饭35',
        context: ParseContext(
          recentCategories: ['餐饮', '交通'],
          customCategories: ['学习资料'],
        ),
      );
      final json = request.toJson();

      expect(json['text'], '午饭35');
      expect(json['context']['recentCategories'], ['餐饮', '交通']);
      expect(json['context']['customCategories'], ['学习资料']);
    });
  });

  group('ApiClient X-API-Key header', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('includes X-API-Key header when apiKey is configured', () async {
      await prefs.setString('api_auth_key', 'test-secret');
      final config = ApiConfig(prefs);
      final client = ApiClient(config);

      expect(client.headers['X-API-Key'], 'test-secret');
      expect(client.headers['Content-Type'], 'application/json');
    });

    test('omits X-API-Key header when apiKey is empty', () {
      final config = ApiConfig(prefs);
      final client = ApiClient(config);

      expect(client.headers.containsKey('X-API-Key'), isFalse);
      expect(client.headers['Content-Type'], 'application/json');
    });

    test('updateApiKey adds header dynamically', () {
      final config = ApiConfig(prefs);
      final client = ApiClient(config);
      expect(client.headers.containsKey('X-API-Key'), isFalse);

      client.updateApiKey('dynamic-key');

      expect(client.headers['X-API-Key'], 'dynamic-key');
    });

    test('updateApiKey with empty string removes header', () async {
      await prefs.setString('api_auth_key', 'to-remove');
      final config = ApiConfig(prefs);
      final client = ApiClient(config);
      expect(client.headers['X-API-Key'], 'to-remove');

      client.updateApiKey('');

      expect(client.headers.containsKey('X-API-Key'), isFalse);
    });

    test('updateApiKey replaces existing key', () async {
      await prefs.setString('api_auth_key', 'old-key');
      final config = ApiConfig(prefs);
      final client = ApiClient(config);

      client.updateApiKey('new-key');

      expect(client.headers['X-API-Key'], 'new-key');
    });
  });

  group('ApiClient HTTP methods', () {
    late SharedPreferences prefs;
    late ApiClient client;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      client = ApiClient(ApiConfig(prefs));
    });

    test('post returns JSON data', () async {
      final client = ApiClient(ApiConfig(prefs));
      final dio = _getDio(client);
      dio.httpClientAdapter = _MockAdapter(
        responseBody: '{"key":"value"}',
        statusCode: 200,
      );

      final result = await client.post('/test', data: {'input': 1});
      expect(result['key'], 'value');
    });

    test('post returns empty map for null body', () async {
      final client = ApiClient(ApiConfig(prefs));
      final dio = _getDio(client);
      dio.httpClientAdapter = _MockAdapter(
        responseBody: '',
        statusCode: 204,
        isNullBody: true,
      );

      final result = await client.post('/test');
      expect(result, isEmpty);
    });

    test('get returns JSON data', () async {
      final client = ApiClient(ApiConfig(prefs));
      final dio = _getDio(client);
      dio.httpClientAdapter = _MockAdapter(
        responseBody: '{"status":"ok"}',
        statusCode: 200,
      );

      final result = await client.get('/test');
      expect(result['status'], 'ok');
    });

    test('healthCheck returns true on 200', () async {
      final client = ApiClient(ApiConfig(prefs));
      final dio = _getDio(client);
      dio.httpClientAdapter = _MockAdapter(
        responseBody: '{"status":"UP"}',
        statusCode: 200,
      );

      expect(await client.healthCheck(), isTrue);
    });

    test('healthCheck returns false on error', () async {
      final client = ApiClient(ApiConfig(prefs));
      final dio = _getDio(client);
      dio.httpClientAdapter = _MockAdapter(
        responseBody: 'error',
        statusCode: 503,
      );

      expect(await client.healthCheck(), isFalse);
    });

    test('updateBaseUrl changes base URL', () {
      final client = ApiClient(ApiConfig(prefs));
      expect(client.baseUrl, 'http://10.0.2.2:8080');

      client.updateBaseUrl('https://api.example.com');
      expect(client.baseUrl, 'https://api.example.com');
    });
  });

  group('RequestIdInterceptor', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('attaches X-Request-ID header to every request', () async {
      final client = ApiClient(ApiConfig(prefs));
      final dio = _getDio(client);
      String? capturedRequestId;
      dio.httpClientAdapter = _CapturingMockAdapter(
        responseBody: '{"ok":true}',
        statusCode: 200,
        onRequest: (options) {
          capturedRequestId = options.headers['X-Request-ID'] as String?;
        },
      );

      await client.get('/test');

      expect(capturedRequestId, isNotNull);
      expect(capturedRequestId!.length, 8);
    });

    test('generates unique IDs per request', () async {
      final client = ApiClient(ApiConfig(prefs));
      final dio = _getDio(client);
      final ids = <String>[];
      dio.httpClientAdapter = _CapturingMockAdapter(
        responseBody: '{"ok":true}',
        statusCode: 200,
        onRequest: (options) {
          ids.add(options.headers['X-Request-ID'] as String);
        },
      );

      await client.get('/test1');
      await client.get('/test2');
      await client.get('/test3');

      expect(ids.length, 3);
      expect(ids.toSet().length, 3);
    });
  });

  group('TransactionParseResponse', () {
    test('fromJson parses complete response', () {
      final json = {
        'amount': 35.0,
        'currency': 'CNY',
        'date': '2026-02-17',
        'category': '餐饮',
        'description': '午饭',
        'type': 'EXPENSE',
        'account': null,
        'confidence': 0.95,
        'model': 'qwen-turbo',
      };

      final response = TransactionParseResponse.fromJson(json);

      expect(response.amount, 35.0);
      expect(response.category, '餐饮');
      expect(response.type, 'EXPENSE');
      expect(response.confidence, 0.95);
      expect(response.isComplete, isTrue);
    });

    test('fromJson handles null amount', () {
      final json = {
        'amount': null,
        'category': '交通',
        'confidence': 0.5,
        'model': 'qwen-turbo',
      };

      final response = TransactionParseResponse.fromJson(json);

      expect(response.amount, isNull);
      expect(response.isComplete, isFalse);
    });

    test('isComplete requires amount and category', () {
      const complete = TransactionParseResponse(
        amount: 35,
        category: '餐饮',
        confidence: 0.9,
        model: 'test',
      );
      const incomplete = TransactionParseResponse(
        amount: 35,
        confidence: 0.5,
        model: 'test',
      );

      expect(complete.isComplete, isTrue);
      expect(incomplete.isComplete, isFalse);
    });
  });
}

Dio _getDio(ApiClient client) => client.dio;

/// Mock HttpClientAdapter that returns a pre-configured response.
class _MockAdapter implements HttpClientAdapter {
  final String responseBody;
  final int statusCode;
  final bool isNullBody;

  _MockAdapter({
    required this.responseBody,
    required this.statusCode,
    this.isNullBody = false,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
          data: responseBody,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    return ResponseBody.fromString(
      isNullBody ? '' : responseBody,
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CapturingMockAdapter implements HttpClientAdapter {
  final String responseBody;
  final int statusCode;
  final void Function(RequestOptions) onRequest;

  _CapturingMockAdapter({
    required this.responseBody,
    required this.statusCode,
    required this.onRequest,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options);
    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
