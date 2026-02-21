import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/network_providers.dart';
import '../widgets/mode_switcher.dart';

const _keyInputMode = 'voice_input_mode';
const _keyHideAutoVoiceMode = 'hide_auto_voice_mode';
const _keyVadSilenceDurationMs = 'voice_vad_silence_duration_ms';

/// VAD silence_duration_ms bounds per Aliyun Qwen-ASR-Realtime.
const vadSilenceDurationMsMin = 200;
const vadSilenceDurationMsMax = 6000;
const vadSilenceDurationMsDefault = 1000;

/// Persists voice input preferences across sessions.
class VoiceSettings {
  final VoiceInputMode inputMode;
  final bool hideAutoVoiceMode;
  final int vadSilenceDurationMs;

  const VoiceSettings({
    this.inputMode = VoiceInputMode.pushToTalk,
    this.hideAutoVoiceMode = false,
    this.vadSilenceDurationMs = vadSilenceDurationMsDefault,
  });

  VoiceSettings copyWith({
    VoiceInputMode? inputMode,
    bool? hideAutoVoiceMode,
    int? vadSilenceDurationMs,
  }) {
    return VoiceSettings(
      inputMode: inputMode ?? this.inputMode,
      hideAutoVoiceMode: hideAutoVoiceMode ?? this.hideAutoVoiceMode,
      vadSilenceDurationMs:
          vadSilenceDurationMs ?? this.vadSilenceDurationMs,
    );
  }
}

/// Manages voice input settings with SharedPreferences persistence.
class VoiceSettingsNotifier extends Notifier<VoiceSettings> {
  @override
  VoiceSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final modeIndex = prefs.getInt(_keyInputMode);
    final inputMode = modeIndex != null &&
            modeIndex >= 0 &&
            modeIndex < VoiceInputMode.values.length
        ? VoiceInputMode.values[modeIndex]
        : VoiceInputMode.pushToTalk;
    // Persist default so fresh install / cleared data always starts as manual (pushToTalk).
    if (modeIndex == null ||
        modeIndex < 0 ||
        modeIndex >= VoiceInputMode.values.length) {
      prefs.setInt(_keyInputMode, VoiceInputMode.pushToTalk.index);
    }
    final hideAutoVoiceMode = prefs.getBool(_keyHideAutoVoiceMode) ?? false;
    final rawMs = prefs.getInt(_keyVadSilenceDurationMs);
    final vadSilenceDurationMs = rawMs != null
        ? rawMs.clamp(vadSilenceDurationMsMin, vadSilenceDurationMsMax)
        : vadSilenceDurationMsDefault;
    return VoiceSettings(
      inputMode: inputMode,
      hideAutoVoiceMode: hideAutoVoiceMode,
      vadSilenceDurationMs: vadSilenceDurationMs,
    );
  }

  void setInputMode(VoiceInputMode mode) {
    state = state.copyWith(inputMode: mode);
    ref.read(sharedPreferencesProvider).setInt(_keyInputMode, mode.index);
  }

  void setHideAutoVoiceMode(bool value) {
    state = state.copyWith(hideAutoVoiceMode: value);
    ref.read(sharedPreferencesProvider).setBool(_keyHideAutoVoiceMode, value);
  }

  void setVadSilenceDurationMs(int value) {
    final clamped =
        value.clamp(vadSilenceDurationMsMin, vadSilenceDurationMsMax);
    state = state.copyWith(vadSilenceDurationMs: clamped);
    ref.read(sharedPreferencesProvider).setInt(_keyVadSilenceDurationMs, clamped);
  }
}

final voiceSettingsProvider =
    NotifierProvider<VoiceSettingsNotifier, VoiceSettings>(
  VoiceSettingsNotifier.new,
);
