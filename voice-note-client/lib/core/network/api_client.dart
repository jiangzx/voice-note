import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'api_config.dart';
import 'api_exceptions.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/request_id_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// Central HTTP client for communicating with voice-note-server.
class ApiClient {
  final Dio _dio;

  ApiClient(ApiConfig config)
      : _dio = Dio(
          BaseOptions(
            baseUrl: config.baseUrl,
            connectTimeout: ApiConfig.defaultTimeout,
            receiveTimeout: ApiConfig.defaultTimeout,
            headers: {
              'Content-Type': 'application/json',
              if (config.apiKey.isNotEmpty) 'X-API-Key': config.apiKey,
            },
          ),
        ) {
    _dio.interceptors.addAll([
      RequestIdInterceptor(),
      LoggingInterceptor(),
      ErrorInterceptor(),
      RetryInterceptor(_dio),
    ]);
  }

  /// Update the API key at runtime (e.g., from settings).
  void updateApiKey(String apiKey) {
    if (apiKey.isEmpty) {
      _dio.options.headers.remove('X-API-Key');
    } else {
      _dio.options.headers['X-API-Key'] = apiKey;
    }
  }

  /// Attach a session-scoped ID to every subsequent request.
  void setSessionId(String sessionId) {
    _dio.options.headers['X-Session-Id'] = sessionId;
  }

  /// Remove the session ID header (call on session end).
  void clearSessionId() {
    _dio.options.headers.remove('X-Session-Id');
  }

  /// POST request that returns decoded JSON map.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      return response.data ?? const {};
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      rethrow;
    }
  }

  /// GET request that returns decoded JSON map.
  Future<Map<String, dynamic>> get(String path) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path);
      return response.data ?? const {};
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      rethrow;
    }
  }

  /// Check if the server is reachable (GET /actuator/health).
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get<dynamic>('/actuator/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Current base URL.
  String get baseUrl => _dio.options.baseUrl;

  /// Current request headers (exposed for testing).
  @visibleForTesting
  Map<String, dynamic> get headers =>
      Map.unmodifiable(_dio.options.headers);

  /// Internal Dio instance (exposed for testing mock adapters).
  @visibleForTesting
  Dio get dio => _dio;

  /// Update the base URL at runtime (e.g., from settings).
  void updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }
}
