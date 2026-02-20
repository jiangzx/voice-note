import 'package:flutter/foundation.dart';

@immutable
class NativeAudioCommand {
  final String sessionId;
  final String? requestId;
  final Map<String, Object?> payload;

  const NativeAudioCommand({
    required this.sessionId,
    this.requestId,
    this.payload = const <String, Object?>{},
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'sessionId': sessionId,
      if (requestId != null) 'requestId': requestId,
      ...payload,
    };
  }
}

@immutable
class NativeAudioSnapshot {
  final String appState;
  final bool captureActive;
  final bool asrMuted;
  final bool ttsPlaying;
  final String focusState;
  final String route;
  final Map<String, Object?> bargeInConfig;

  const NativeAudioSnapshot({
    required this.appState,
    required this.captureActive,
    required this.asrMuted,
    required this.ttsPlaying,
    required this.focusState,
    required this.route,
    this.bargeInConfig = const <String, Object?>{},
  });

  factory NativeAudioSnapshot.fromMap(Map<Object?, Object?> raw) {
    return NativeAudioSnapshot(
      appState: raw['appState'] as String? ?? 'unknown',
      captureActive: raw['captureActive'] as bool? ?? false,
      asrMuted: raw['asrMuted'] as bool? ?? false,
      ttsPlaying: raw['ttsPlaying'] as bool? ?? false,
      focusState: raw['focusState'] as String? ?? 'unknown',
      route: raw['route'] as String? ?? 'unknown',
      bargeInConfig: (raw['bargeInConfig'] as Map<Object?, Object?>?)
              ?.cast<String, Object?>() ??
          const <String, Object?>{},
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'appState': appState,
      'captureActive': captureActive,
      'asrMuted': asrMuted,
      'ttsPlaying': ttsPlaying,
      'focusState': focusState,
      'route': route,
      'bargeInConfig': bargeInConfig,
    };
  }
}

@immutable
class NativeAudioError {
  static const String codeInvalidArgument = 'invalid_argument';
  static const String codeNotInitialized = 'not_initialized';
  static const String codeInitFailed = 'init_failed';
  static const String codeTtsUnavailable = 'tts_unavailable';
  static const String codeTtsFailed = 'tts_failed';
  static const String codeInternalError = 'internal_error';

  final String code;
  final String message;
  final String? rawCode;

  const NativeAudioError({
    required this.code,
    required this.message,
    this.rawCode,
  });

  factory NativeAudioError.fromMap(Map<Object?, Object?> raw) {
    final String rawCode =
        raw['rawCode'] as String? ??
        raw['code'] as String? ??
        'unknown_error';
    final String normalizedCode = _normalizeCode(rawCode);
    return NativeAudioError(
      code: normalizedCode,
      message: raw['message'] as String? ?? 'Unknown native audio error',
      rawCode: rawCode,
    );
  }

  static String _normalizeCode(String rawCode) {
    if (rawCode == 'missing_session_id' || rawCode == 'missing_snapshot') {
      return codeInvalidArgument;
    }
    if (rawCode == 'invalid_event_payload') return codeInvalidArgument;
    if (rawCode == 'not_initialized') return codeNotInitialized;
    if (rawCode.endsWith('_init_failed')) return codeInitFailed;
    if (rawCode == 'tts_not_ready') return codeTtsUnavailable;
    if (rawCode.startsWith('tts_error')) return codeTtsFailed;
    if (rawCode == codeInvalidArgument ||
        rawCode == codeNotInitialized ||
        rawCode == codeInitFailed ||
        rawCode == codeTtsUnavailable ||
        rawCode == codeTtsFailed ||
        rawCode == codeInternalError) {
      return rawCode;
    }
    return codeInternalError;
  }
}

@immutable
class NativeAudioEvent {
  final String event;
  final String sessionId;
  final String? requestId;
  final int timestamp;
  final Map<String, Object?> data;
  final NativeAudioError? error;

  const NativeAudioEvent({
    required this.event,
    required this.sessionId,
    required this.timestamp,
    this.requestId,
    this.data = const <String, Object?>{},
    this.error,
  });

  // Unified resume semantic: platform payload wins, otherwise infer from
  // successful playback completion/stop events.
  bool get canAutoResume =>
      (data['canAutoResume'] as bool?) ??
      (error == null && (event == 'ttsCompleted' || event == 'ttsStopped'));

  String get route => data['route'] as String? ?? 'unknown';
  String get focusState => data['focusState'] as String? ?? 'unknown';

  factory NativeAudioEvent.fromMap(Map<Object?, Object?> raw) {
    final Object? errorRaw = raw['error'];
    return NativeAudioEvent(
      event: raw['event'] as String? ?? 'runtimeError',
      sessionId: raw['sessionId'] as String? ?? '',
      requestId: raw['requestId'] as String?,
      timestamp: raw['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      data: (raw['data'] as Map<Object?, Object?>?)?.cast<String, Object?>() ??
          const <String, Object?>{},
      error: errorRaw is Map<Object?, Object?>
          ? NativeAudioError.fromMap(errorRaw)
          : null,
    );
  }
}
