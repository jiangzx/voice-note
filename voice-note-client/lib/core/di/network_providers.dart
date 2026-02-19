import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_config.dart';
import '../network/network_status_service.dart';

part 'network_providers.g.dart';

@Riverpod(keepAlive: true)
ApiConfig apiConfig(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiConfig(prefs);
}

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) {
  final config = ref.watch(apiConfigProvider);
  return ApiClient(config);
}

/// SharedPreferences instance. Must be overridden in ProviderScope at app
/// startup with an already-initialized instance.
@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
}

/// Network connectivity monitor (manual provider — no codegen needed).
/// Call `init()` at app startup, e.g. via ProviderScope override or eager read.
final networkStatusServiceProvider = Provider<NetworkStatusService>((ref) {
  final service = NetworkStatusService();
  ref.onDispose(() => service.dispose());
  return service;
});
