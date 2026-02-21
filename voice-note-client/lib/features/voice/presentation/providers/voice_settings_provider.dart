import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/network_providers.dart';
import '../widgets/mode_switcher.dart';

const _keyInputMode = 'voice_input_mode';
const _keyHideAutoVoiceMode = 'hide_auto_voice_mode';

/// Persists voice input preferences across sessions.
class VoiceSettings {
  final VoiceInputMode inputMode;
  final bool hideAutoVoiceMode;

  const VoiceSettings({
    this.inputMode = VoiceInputMode.pushToTalk,
    this.hideAutoVoiceMode = false,
  });

  VoiceSettings copyWith({
    VoiceInputMode? inputMode,
    bool? hideAutoVoiceMode,
  }) {
    return VoiceSettings(
      inputMode: inputMode ?? this.inputMode,
      hideAutoVoiceMode: hideAutoVoiceMode ?? this.hideAutoVoiceMode,
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
    final hideAutoVoiceMode = prefs.getBool(_keyHideAutoVoiceMode) ?? false;
    return VoiceSettings(
      inputMode: inputMode,
      hideAutoVoiceMode: hideAutoVoiceMode,
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
}

final voiceSettingsProvider =
    NotifierProvider<VoiceSettingsNotifier, VoiceSettings>(
  VoiceSettingsNotifier.new,
);
