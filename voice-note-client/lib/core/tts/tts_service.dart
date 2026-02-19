import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys for persisting TTS settings.
const _kTtsEnabled = 'tts_enabled';
const _kTtsSpeed = 'tts_speed';

/// Wraps the system TTS engine with enable/disable toggle and speech rate
/// persistence. Gracefully degrades to silent mode if TTS is unavailable.
class TtsService {
  final FlutterTts _tts;
  final SharedPreferences _prefs;

  bool _available = false;
  bool _enabled = false;
  double _speechRate = 1.0;
  bool _isSpeaking = false;
  bool _initialized = false;
  Completer<void>? _speakCompleter;

  TtsService({
    required SharedPreferences prefs,
    FlutterTts? tts,
  })  : _prefs = prefs,
        _tts = tts ?? FlutterTts();

  // ======================== Getters ========================

  bool get available => _available;
  bool get enabled => _enabled;
  double get speechRate => _speechRate;
  bool get isSpeaking => _isSpeaking;

  // ======================== Lifecycle ========================

  /// Initialize TTS engine and load persisted settings. Idempotent.
  Future<void> init() async {
    if (_initialized) {
      if (kDebugMode) debugPrint('[TTSFlow] Already initialized, skipping');
      return;
    }
    _initialized = true;

    _enabled = _prefs.getBool(_kTtsEnabled) ?? true;
    _speechRate = _prefs.getDouble(_kTtsSpeed) ?? 1.0;
    if (kDebugMode) debugPrint('[TTSFlow] init: enabled=$_enabled, speechRate=$_speechRate');

    try {
      await _tts.setLanguage('zh-CN');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(1.0);
      _available = true;

      _tts.setCompletionHandler(_onComplete);
      _tts.setCancelHandler(_onComplete);
      _tts.setErrorHandler((_) => _onComplete());
      if (kDebugMode) debugPrint('[TTSFlow] Engine ready: available=$_available');
    } catch (e) {
      if (kDebugMode) debugPrint('[TTSFlow] INIT FAILED, degrading to silent: $e');
      _available = false;
    }
  }

  /// Dispose TTS engine resources.
  Future<void> dispose() async {
    _speakCompleter?.complete();
    _speakCompleter = null;
    _isSpeaking = false;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  // ======================== Public API ========================

  /// Speak the given [text]. Returns a Future that resolves when speech
  /// completes. If TTS is disabled or unavailable, resolves immediately.
  /// Calling speak while already speaking stops the previous utterance.
  Future<void> speak(String text) async {
    if (!_enabled || !_available || text.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[TTSFlow] speak() SKIPPED: enabled=$_enabled, available=$_available, '
          'textEmpty=${text.isEmpty}',
        );
      }
      return;
    }

    if (_isSpeaking) {
      if (kDebugMode) debugPrint('[TTSFlow] Stopping previous speech before new one');
      await stop();
    }

    _isSpeaking = true;
    _speakCompleter = Completer<void>();
    if (kDebugMode) debugPrint('[TTSFlow] Speaking: "${text.substring(0, text.length.clamp(0, 30))}..."');

    try {
      await _tts.speak(text);
      await _speakCompleter!.future;
      if (kDebugMode) debugPrint('[TTSFlow] Speech completed OK');
    } catch (e) {
      if (kDebugMode) debugPrint('[TTSFlow] SPEAK FAILED: $e');
    } finally {
      _isSpeaking = false;
      _speakCompleter = null;
    }
  }

  /// Stop the current speech immediately.
  Future<void> stop() async {
    if (!_available) return;
    try {
      await _tts.stop();
    } catch (_) {}
    _onComplete();
  }

  /// Enable or disable TTS and persist the setting.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs.setBool(_kTtsEnabled, value);
    if (!value && _isSpeaking) {
      await stop();
    }
  }

  /// Set speech rate (0.5 - 2.0) and persist the setting.
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.5, 2.0);
    await _prefs.setDouble(_kTtsSpeed, _speechRate);
    if (_available) {
      try {
        await _tts.setSpeechRate(_speechRate);
      } catch (_) {}
    }
  }

  // ======================== Internal ========================

  void _onComplete() {
    if (_speakCompleter != null && !_speakCompleter!.isCompleted) {
      _speakCompleter!.complete();
    }
    _isSpeaking = false;
  }
}
