import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Centralized audio session configuration for voice assistant flow.
class AudioSessionService {
  bool _configured = false;

  Future<void> configureForVoiceAssistant() async {
    if (_configured) {
      if (kDebugMode) debugPrint('[AudioInit] Already configured, skipping');
      return;
    }

    if (kDebugMode) debugPrint('[AudioInit] Configuring audio session for voice assistant...');
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ),
      );
      _configured = true;
      if (kDebugMode) debugPrint('[AudioInit] Audio session configured OK');
    } catch (e) {
      if (kDebugMode) debugPrint('[AudioInit] FAILED: $e');
    }
  }
}
