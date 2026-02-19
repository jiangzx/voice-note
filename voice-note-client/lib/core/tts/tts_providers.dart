import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/network_providers.dart';
import 'tts_service.dart';

/// Provides a singleton [TtsService] initialized with SharedPreferences.
/// Call [TtsService.init] once at app startup or on first access.
final ttsServiceProvider = Provider<TtsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return TtsService(prefs: prefs);
});
