import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/mode_switcher.dart';

/// Persists voice input preferences across sessions.
class VoiceSettings {
  final VoiceInputMode inputMode;

  const VoiceSettings({this.inputMode = VoiceInputMode.auto});

  VoiceSettings copyWith({VoiceInputMode? inputMode}) {
    return VoiceSettings(inputMode: inputMode ?? this.inputMode);
  }
}

/// Manages voice input settings.
class VoiceSettingsNotifier extends Notifier<VoiceSettings> {
  @override
  VoiceSettings build() => const VoiceSettings();

  void setInputMode(VoiceInputMode mode) {
    state = state.copyWith(inputMode: mode);
  }
}

final voiceSettingsProvider =
    NotifierProvider<VoiceSettingsNotifier, VoiceSettings>(
  VoiceSettingsNotifier.new,
);
