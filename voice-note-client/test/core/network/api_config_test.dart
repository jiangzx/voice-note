import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/network/api_config.dart';

void main() {
  group('ApiConfig', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('baseUrl returns default when not set', () {
      final config = ApiConfig(prefs);
      expect(config.baseUrl, 'http://10.0.2.2:8080');
    });

    test('setBaseUrl persists and returns new URL', () async {
      final config = ApiConfig(prefs);

      await config.setBaseUrl('http://example.com:9090');

      expect(config.baseUrl, 'http://example.com:9090');
    });

    test('resetBaseUrl restores default', () async {
      final config = ApiConfig(prefs);
      await config.setBaseUrl('http://example.com');

      await config.resetBaseUrl();

      expect(config.baseUrl, 'http://10.0.2.2:8080');
    });

    test('apiKey returns empty string when not set', () {
      final config = ApiConfig(prefs);
      expect(config.apiKey, '');
    });

    test('setApiKey persists and returns the key', () async {
      final config = ApiConfig(prefs);

      await config.setApiKey('my-secret-key');

      expect(config.apiKey, 'my-secret-key');
    });

    test('clearApiKey removes the stored key', () async {
      final config = ApiConfig(prefs);
      await config.setApiKey('my-secret-key');

      await config.clearApiKey();

      expect(config.apiKey, '');
    });

    test('apiKey and baseUrl are independent', () async {
      final config = ApiConfig(prefs);

      await config.setBaseUrl('http://test.com');
      await config.setApiKey('key-123');

      expect(config.baseUrl, 'http://test.com');
      expect(config.apiKey, 'key-123');

      await config.resetBaseUrl();
      expect(config.apiKey, 'key-123');

      await config.clearApiKey();
      expect(config.baseUrl, 'http://10.0.2.2:8080');
    });

    test('defaultTimeout is 15 seconds', () {
      expect(ApiConfig.defaultTimeout, const Duration(seconds: 15));
    });
  });
}
