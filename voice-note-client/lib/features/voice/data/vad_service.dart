import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:vad/vad.dart';

/// Frame-level data from VAD processing.
typedef VadFrameData = ({double isSpeech, double notSpeech, List<double> frame});

/// Wraps Silero VAD for local voice activity detection.
///
/// Provides speech start/end events to control ASR connection lifecycle
/// (connect on speech start, disconnect on speech end → zero cloud cost
/// during silence).
class VadService {
  final VadHandler _handler;
  bool _isListening = false;

  // Configurable thresholds
  final double positiveSpeechThreshold;
  final double negativeSpeechThreshold;
  final int preSpeechPadFrames;
  final int redemptionFrames;
  final int minSpeechFrames;

  VadService({
    VadHandler? handler,
    this.positiveSpeechThreshold = 0.5,
    this.negativeSpeechThreshold = 0.35,
    this.preSpeechPadFrames = 3,
    this.redemptionFrames = 8,
    this.minSpeechFrames = 3,
  }) : _handler = handler ?? VadHandler.create(isDebug: false);

  bool get isListening => _isListening;

  /// Fires when speech begins (initial detection, may be a misfire).
  Stream<void> get onSpeechStart => _handler.onSpeechStart;

  /// Fires when real speech starts (exceeds minimum frames threshold).
  Stream<void> get onRealSpeechStart => _handler.onRealSpeechStart;

  /// Fires when speech ends. Provides audio samples of the speech segment.
  Stream<List<double>> get onSpeechEnd => _handler.onSpeechEnd;

  /// Fires when initial speech detection was too short (misfire).
  Stream<void> get onVADMisfire => _handler.onVADMisfire;

  /// Fires for every processed audio frame with speech probability.
  Stream<VadFrameData> get onFrameProcessed => _handler.onFrameProcessed;

  /// Fires on error.
  Stream<String> get onError => _handler.onError;

  /// Start VAD listening.
  /// If [audioStream] is provided, uses it instead of built-in recorder.
  Future<void> start({Stream<Uint8List>? audioStream}) async {
    if (_isListening) {
      dev.log('[VADFlow] Already listening, skipping', name: 'VadService');
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[VADFlow] Starting: threshold=+$positiveSpeechThreshold/-$negativeSpeechThreshold, '
        'minFrames=$minSpeechFrames, hasExternalStream=${audioStream != null}',
      );
    }
    try {
      await _handler.startListening(
        positiveSpeechThreshold: positiveSpeechThreshold,
        negativeSpeechThreshold: negativeSpeechThreshold,
        preSpeechPadFrames: preSpeechPadFrames,
        redemptionFrames: redemptionFrames,
        minSpeechFrames: minSpeechFrames,
        model: 'v5',
        frameSamples: 512,
        audioStream: audioStream,
      );
      _isListening = true;
      if (kDebugMode) debugPrint('[VADFlow] Started OK, waiting for speech events...');
    } catch (e) {
      _isListening = false;
      if (kDebugMode) debugPrint('[VADFlow] START FAILED: $e');
      throw VadServiceException('Failed to start VAD: $e');
    }
  }

  /// Pause VAD without fully stopping (keeps audio stream alive).
  Future<void> pause() async {
    if (!_isListening) return;
    try {
      await _handler.pauseListening();
    } catch (_) {
      // Best-effort
    }
    _isListening = false;
  }

  /// Stop VAD listening completely.
  Future<void> stop() async {
    if (!_isListening) return;
    try {
      await _handler.stopListening();
    } catch (_) {
      // Best-effort
    }
    _isListening = false;
  }

  /// Release all resources.
  Future<void> dispose() async {
    await stop();
    try {
      await _handler.dispose();
    } catch (_) {
      // Best-effort
    }
  }
}

/// Thrown when VAD service encounters an unrecoverable error.
class VadServiceException implements Exception {
  final String message;
  const VadServiceException(this.message);

  @override
  String toString() => 'VadServiceException: $message';
}
