import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for persisting TTS settings.
const _kTtsEnabled = 'tts_enabled';
const _kTtsSpeed = 'tts_speed';

/// Manages TTS settings (enabled/disabled and speech rate).
///
/// Note: Actual TTS playback is handled by native layer via NativeAudioGateway.
/// This service only manages user preferences for TTS settings.
class TtsService {
  final SharedPreferences _prefs;

  bool _enabled = false;
  double _speechRate = 1.8;
  bool _initialized = false;

  TtsService({
    required SharedPreferences prefs,
  }) : _prefs = prefs;

  // ======================== Getters ========================

  bool get enabled => _enabled;
  double get speechRate => _speechRate;

  // ======================== Lifecycle ========================

  /// Initialize and load persisted settings. Idempotent.
  Future<void> init() async {
    if (_initialized) {
      if (kDebugMode) debugPrint('[TTSFlow] Already initialized, skipping');
      return;
    }
    _initialized = true;

    _enabled = _prefs.getBool(_kTtsEnabled) ?? true;
    _speechRate = _prefs.getDouble(_kTtsSpeed) ?? 1.8;
    if (kDebugMode) {
      debugPrint('[TTSFlow] init: enabled=$_enabled, speechRate=$_speechRate');
    }
  }

  // ======================== Public API ========================

  /// Enable or disable TTS and persist the setting.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs.setBool(_kTtsEnabled, value);
  }

  /// Set speech rate (0.5 - 2.0) and persist the setting.
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 2.0);
    await _prefs.setDouble(_kTtsSpeed, _speechRate);
  }
}
