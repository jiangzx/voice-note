import 'package:shared_preferences/shared_preferences.dart';

/// Server connection configuration.
class ApiConfig {
  static const _keyBaseUrl = 'api_base_url';
  static const _keyApiKey = 'api_auth_key';
  static const _defaultBaseUrl = 'http://192.168.100.190:8090';
  static const defaultTimeout = Duration(seconds: 15);

  final SharedPreferences _prefs;

  ApiConfig(this._prefs);

  String get baseUrl => _prefs.getString(_keyBaseUrl) ?? _defaultBaseUrl;

  /// API key for server authentication (empty = no auth).
  String get apiKey => _prefs.getString(_keyApiKey) ?? '';

  Future<void> setBaseUrl(String url) async {
    await _prefs.setString(_keyBaseUrl, url);
  }

  Future<void> resetBaseUrl() async {
    await _prefs.remove(_keyBaseUrl);
  }

  Future<void> setApiKey(String key) async {
    await _prefs.setString(_keyApiKey, key);
  }

  Future<void> clearApiKey() async {
    await _prefs.remove(_keyApiKey);
  }
}
