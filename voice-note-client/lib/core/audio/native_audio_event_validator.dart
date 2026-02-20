class NativeAudioEventValidationResult {
  final bool valid;
  final String? message;

  const NativeAudioEventValidationResult._({
    required this.valid,
    this.message,
  });

  const NativeAudioEventValidationResult.ok() : this._(valid: true);

  const NativeAudioEventValidationResult.fail(String message)
      : this._(valid: false, message: message);
}

class NativeAudioEventValidator {
  static const Set<String> _supportedEvents = <String>{
    'runtimeInitialized',
    'asrMuteStateChanged',
    'ttsStarted',
    'ttsCompleted',
    'ttsStopped',
    'ttsError',
    'ttsInitDiagnostics',
    'bargeInTriggered',
    'bargeInCompleted',
    'audioFocusChanged',
    'audioRouteChanged',
    'asrInterimText',
    'asrFinalText',
    'runtimeError',
  };

  static NativeAudioEventValidationResult validate(
    Map<Object?, Object?> event,
  ) {
    final Object? eventNameRaw = event['event'];
    if (eventNameRaw is! String || eventNameRaw.isEmpty) {
      return const NativeAudioEventValidationResult.fail(
        'Missing or invalid "event" field',
      );
    }
    if (!_supportedEvents.contains(eventNameRaw)) {
      return NativeAudioEventValidationResult.fail(
        'Unsupported event "$eventNameRaw"',
      );
    }

    if (event['sessionId'] is! String) {
      return const NativeAudioEventValidationResult.fail(
        'Missing or invalid "sessionId" field',
      );
    }
    if (event['timestamp'] is! int) {
      return const NativeAudioEventValidationResult.fail(
        'Missing or invalid "timestamp" field',
      );
    }
    final Object? dataRaw = event['data'];
    if (dataRaw != null && dataRaw is! Map<Object?, Object?>) {
      return const NativeAudioEventValidationResult.fail(
        'Invalid "data" field type',
      );
    }

    final Map<Object?, Object?> data = dataRaw is Map<Object?, Object?>
        ? dataRaw
        : const <Object?, Object?>{};
    final Object? errorRaw = event['error'];
    if (errorRaw != null) {
      if (errorRaw is! Map<Object?, Object?>) {
        return const NativeAudioEventValidationResult.fail(
          'Invalid "error" field type',
        );
      }
      if (errorRaw['code'] is! String || errorRaw['message'] is! String) {
        return const NativeAudioEventValidationResult.fail(
          'Invalid "error" payload: requires "code" and "message"',
        );
      }
    }

    return _validateByEventType(eventNameRaw, data, errorRaw);
  }

  static NativeAudioEventValidationResult _validateByEventType(
    String eventName,
    Map<Object?, Object?> data,
    Object? errorRaw,
  ) {
    switch (eventName) {
      case 'runtimeInitialized':
        return _requireStringFields(data, <String>['focusState', 'route']);
      case 'asrMuteStateChanged':
        return _requireBoolFields(data, <String>['asrMuted']);
      case 'ttsStarted':
        return _requireBoolFields(data, <String>['ttsPlaying']);
      case 'ttsCompleted':
      case 'ttsStopped':
        return _requireBoolFields(data, <String>['ttsPlaying', 'canAutoResume']);
      case 'ttsError':
        final base = _requireBoolFields(
          data,
          <String>['ttsPlaying', 'canAutoResume'],
        );
        if (!base.valid) return base;
        if (errorRaw == null) {
          return const NativeAudioEventValidationResult.fail(
            '"ttsError" must include "error" payload',
          );
        }
        return const NativeAudioEventValidationResult.ok();
      case 'ttsInitDiagnostics':
        // Diagnostic event with optional fields - no strict validation required
        return const NativeAudioEventValidationResult.ok();
      case 'bargeInTriggered':
        final strings = _requireStringFields(
          data,
          <String>['triggerSource', 'route', 'focusState'],
        );
        if (!strings.valid) return strings;
        return _requireBoolFields(data, <String>['canAutoResume']);
      case 'bargeInCompleted':
        return _requireBoolFields(data, <String>['success', 'canAutoResume']);
      case 'audioFocusChanged':
        final strings = _requireStringFields(data, <String>['focusState']);
        if (!strings.valid) return strings;
        return _requireBoolFields(data, <String>['canAutoResume']);
      case 'audioRouteChanged':
        return _requireStringFields(
          data,
          <String>['oldRoute', 'newRoute', 'reason'],
        );
      case 'asrInterimText':
      case 'asrFinalText':
        return _requireStringFields(data, <String>['text']);
      case 'runtimeError':
        if (errorRaw == null) {
          return const NativeAudioEventValidationResult.fail(
            '"runtimeError" must include "error" payload',
          );
        }
        return const NativeAudioEventValidationResult.ok();
      default:
        return const NativeAudioEventValidationResult.fail(
          'Unsupported event type',
        );
    }
  }

  static NativeAudioEventValidationResult _requireStringFields(
    Map<Object?, Object?> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is! String || value.isEmpty) {
        return NativeAudioEventValidationResult.fail(
          'Invalid "$key" field for event payload',
        );
      }
    }
    return const NativeAudioEventValidationResult.ok();
  }

  static NativeAudioEventValidationResult _requireBoolFields(
    Map<Object?, Object?> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (data[key] is! bool) {
        return NativeAudioEventValidationResult.fail(
          'Invalid "$key" field for event payload',
        );
      }
    }
    return const NativeAudioEventValidationResult.ok();
  }
}
