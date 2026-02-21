import 'dart:async';

import 'package:flutter/services.dart';

import 'native_audio_event_validator.dart';
import 'native_audio_models.dart';

class NativeAudioGateway {
  static const MethodChannel _methodChannel =
      MethodChannel('voice_note/native_audio');
  static const EventChannel _eventChannel =
      EventChannel('voice_note/native_audio/events');

  Stream<NativeAudioEvent>? _sharedEvents;

  Stream<NativeAudioEvent> get events {
    // Keep a shared broadcast stream so multiple listeners don't create
    // duplicated native subscriptions.
    _sharedEvents ??= _eventChannel
        .receiveBroadcastStream()
        .map((dynamic event) {
          if (event is Map<Object?, Object?>) {
            final validation = NativeAudioEventValidator.validate(event);
            if (!validation.valid) {
              return NativeAudioEvent(
                event: 'runtimeError',
                sessionId: event['sessionId'] as String? ?? '',
                timestamp:
                    event['timestamp'] as int? ??
                    DateTime.now().millisecondsSinceEpoch,
                error: NativeAudioError(
                  code: NativeAudioError.codeInvalidArgument,
                  message:
                      'Invalid native audio event payload: ${validation.message}',
                  rawCode: 'invalid_event_payload',
                ),
              );
            }
            return NativeAudioEvent.fromMap(event);
          }
          return NativeAudioEvent(
            event: 'runtimeError',
            sessionId: '',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            error: NativeAudioError(
              code: 'invalid_event',
              message: 'Unexpected event payload type: ${event.runtimeType}',
            ),
          );
        })
        .asBroadcastStream();
    return _sharedEvents!;
  }

  Future<Map<Object?, Object?>> initializeSession({
    required String sessionId,
    required String mode,
    int sampleRate = 16000,
    int channels = 1,
    bool enableBargeIn = true,
    Map<String, Object?> platformConfig = const <String, Object?>{},
  }) async {
    final NativeAudioCommand cmd = NativeAudioCommand(
      sessionId: sessionId,
      payload: <String, Object?>{
        'mode': mode,
        'sampleRate': sampleRate,
        'channels': channels,
        'enableBargeIn': enableBargeIn,
        'platformConfig': platformConfig,
      },
    );
    return _invokeMap('initializeSession', cmd.toMap());
  }

  Future<Map<Object?, Object?>> disposeSession(String sessionId) {
    return _invokeMap(
      'disposeSession',
      NativeAudioCommand(sessionId: sessionId).toMap(),
    );
  }

  Future<Map<Object?, Object?>> setAsrMuted({
    required String sessionId,
    required bool muted,
    String reason = 'unspecified',
  }) {
    return _invokeMap(
      'setAsrMuted',
      NativeAudioCommand(
        sessionId: sessionId,
        payload: <String, Object?>{'muted': muted, 'reason': reason},
      ).toMap(),
    );
  }

  Future<Map<Object?, Object?>> playTts({
    required String sessionId,
    required String requestId,
    required String text,
    String locale = 'zh-CN',
    double speechRate = 1.0,
    bool interruptible = true,
  }) {
    return _invokeMap(
      'playTts',
      NativeAudioCommand(
        sessionId: sessionId,
        requestId: requestId,
        payload: <String, Object?>{
          'text': text,
          'locale': locale,
          'speechRate': speechRate,
          'interruptible': interruptible,
        },
      ).toMap(),
    );
  }

  Future<Map<Object?, Object?>> stopTts({
    required String sessionId,
    String? requestId,
    String reason = 'unspecified',
  }) {
    return _invokeMap(
      'stopTts',
      NativeAudioCommand(
        sessionId: sessionId,
        requestId: requestId,
        payload: <String, Object?>{'reason': reason},
      ).toMap(),
    );
  }

  Future<Map<Object?, Object?>> setBargeInConfig({
    required String sessionId,
    required bool enabled,
    double energyThreshold = 0.5,
    int minSpeechMs = 120,
    int cooldownMs = 300,
  }) {
    return _invokeMap(
      'setBargeInConfig',
      NativeAudioCommand(
        sessionId: sessionId,
        payload: <String, Object?>{
          'enabled': enabled,
          'energyThreshold': energyThreshold,
          'minSpeechMs': minSpeechMs,
          'cooldownMs': cooldownMs,
        },
      ).toMap(),
    );
  }

  Future<Map<Object?, Object?>> startCapture({
    required String sessionId,
  }) {
    return _invokeMap(
      'startCapture',
      NativeAudioCommand(
        sessionId: sessionId,
        payload: const <String, Object?>{},
      ).toMap(),
    );
  }

  Future<Map<Object?, Object?>> stopCapture({
    required String sessionId,
  }) {
    return _invokeMap(
      'stopCapture',
      NativeAudioCommand(
        sessionId: sessionId,
        payload: const <String, Object?>{},
      ).toMap(),
    );
  }

  Future<Map<Object?, Object?>> getDuplexStatus(String sessionId) {
    return _invokeMap(
      'getDuplexStatus',
      NativeAudioCommand(sessionId: sessionId).toMap(),
    );
  }

  Future<Map<Object?, Object?>> switchInputMode({
    required String sessionId,
    required String mode,
  }) {
    return _invokeMap(
      'switchInputMode',
      NativeAudioCommand(
        sessionId: sessionId,
        payload: <String, Object?>{'mode': mode},
      ).toMap(),
    );
  }

  Future<Map<Object?, Object?>> startAsrStream({
    required String sessionId,
    required String token,
    required String wsUrl,
    required String model,
    int vadSilenceDurationMs = 1000,
  }) {
    return _invokeMap(
      'startAsrStream',
      NativeAudioCommand(
        sessionId: sessionId,
        payload: <String, Object?>{
          'token': token,
          'wsUrl': wsUrl,
          'model': model,
          'vadSilenceDurationMs': vadSilenceDurationMs,
        },
      ).toMap(),
    );
  }

  Future<Map<Object?, Object?>> commitAsr(String sessionId) {
    return _invokeMap(
      'commitAsr',
      NativeAudioCommand(sessionId: sessionId).toMap(),
    );
  }

  Future<Map<Object?, Object?>> stopAsrStream(String sessionId) {
    return _invokeMap(
      'stopAsrStream',
      NativeAudioCommand(sessionId: sessionId).toMap(),
    );
  }

  Future<NativeAudioSnapshot> getLifecycleSnapshot(String sessionId) async {
    final Map<Object?, Object?> result = await _invokeMap(
      'getLifecycleSnapshot',
      NativeAudioCommand(sessionId: sessionId).toMap(),
    );
    return NativeAudioSnapshot.fromMap(result);
  }

  Future<Map<Object?, Object?>> restoreLifecycleSnapshot({
    required String sessionId,
    required NativeAudioSnapshot snapshot,
  }) {
    return _invokeMap(
      'restoreLifecycleSnapshot',
      NativeAudioCommand(
        sessionId: sessionId,
        payload: <String, Object?>{'snapshot': snapshot.toMap()},
      ).toMap(),
    );
  }

  Future<Map<Object?, Object?>> _invokeMap(
    String method,
    Map<String, Object?> arguments,
  ) async {
    // Native side may return null/void on best-effort paths; normalize to empty map.
    final dynamic result =
        await _methodChannel.invokeMethod<dynamic>(method, arguments);
    if (result is Map<Object?, Object?>) return result;
    return <Object?, Object?>{};
  }
}
