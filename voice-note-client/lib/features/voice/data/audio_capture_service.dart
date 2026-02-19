import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

/// Captures PCM16 16kHz mono audio from the microphone
/// and provides a broadcast stream for multiple consumers (VAD + ASR).
class AudioCaptureService {
  final AudioRecorder _recorder;
  StreamController<Uint8List>? _controller;
  StreamSubscription<Uint8List>? _subscription;
  _AudioRingBuffer? _ringBuffer;

  static const int sampleRate = 16000;
  static const int numChannels = 1;

  /// Bytes per millisecond: 16kHz * 16bit * mono = 32 bytes/ms.
  static const int bytesPerMs = 32;

  AudioCaptureService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  bool get isCapturing => _controller != null && !_controller!.isClosed;

  /// Broadcast audio stream. Emits raw PCM16 16kHz mono chunks.
  Stream<Uint8List>? get audioStream => _controller?.stream;

  /// Start capturing audio from microphone.
  /// [preBufferMs] — how many ms of pre-speech audio to keep in ring buffer.
  Future<void> start({int preBufferMs = 500}) async {
    if (isCapturing) {
      dev.log('[AudioInput] Already capturing, skipping', name: 'AudioCapture');
      return;
    }

    if (kDebugMode) debugPrint('[AudioInput] Checking mic permission...');
    final hasPermission = await _recorder.hasPermission();
    if (kDebugMode) debugPrint('[AudioInput] Permission result: $hasPermission');
    if (!hasPermission) {
      throw const AudioCaptureException('Microphone permission not granted');
    }

    _ringBuffer = _AudioRingBuffer(maxBytes: preBufferMs * bytesPerMs);
    _controller = StreamController<Uint8List>.broadcast();
    int chunkCount = 0;
    int totalZeroChunks = 0;

    try {
      if (kDebugMode) {
        debugPrint(
          '[AudioInput] Starting stream: PCM16 ${sampleRate}Hz mono, '
          'preBuffer=${preBufferMs}ms',
        );
      }
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: numChannels,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
      );

      _subscription = stream.listen(
        (data) {
          chunkCount++;
          final allZero = data.every((b) => b == 0);
          if (allZero) totalZeroChunks++;
          if (chunkCount <= 5 || chunkCount % 100 == 0) {
            if (kDebugMode) {
              debugPrint(
                '[AudioInput] Chunk #$chunkCount: ${data.length} bytes, '
                'allZero=$allZero, zeroTotal=$totalZeroChunks',
              );
            }
          }
          _ringBuffer?.add(data);
          _controller?.add(data);
        },
        onError: (Object error) {
          if (kDebugMode) debugPrint('[AudioInput] Stream ERROR: $error');
          _controller?.addError(error);
        },
        onDone: () {
          if (kDebugMode) debugPrint('[AudioInput] Stream DONE after $chunkCount chunks ($totalZeroChunks zero)');
          _controller?.close();
        },
      );
      if (kDebugMode) debugPrint('[AudioInput] Capture started OK');
    } catch (e) {
      if (kDebugMode) debugPrint('[AudioInput] START FAILED: $e');
      await _controller?.close();
      _controller = null;
      _ringBuffer = null;
      throw AudioCaptureException('Failed to start audio stream: $e');
    }
  }

  /// Drain the ring buffer (pre-speech audio) and return accumulated chunks.
  /// Useful for sending buffered audio to ASR when speech is detected.
  List<Uint8List> drainPreBuffer() => _ringBuffer?.drain() ?? [];

  /// Stop capturing audio.
  Future<void> stop() async {
    try {
      await _subscription?.cancel();
    } catch (_) {
      // Best-effort cleanup
    }
    _subscription = null;
    try {
      await _recorder.stop();
    } catch (_) {
      // Best-effort cleanup
    }
    try {
      await _controller?.close();
    } catch (_) {
      // Best-effort cleanup
    }
    _controller = null;
    _ringBuffer = null;
  }

  /// Release all resources.
  Future<void> dispose() async {
    await stop();
    try {
      _recorder.dispose();
    } catch (_) {
      // Best-effort cleanup
    }
  }
}

/// Fixed-size ring buffer that retains the most recent N bytes of audio.
class _AudioRingBuffer {
  final int maxBytes;
  final Queue<Uint8List> _queue = Queue<Uint8List>();
  int _size = 0;

  _AudioRingBuffer({required this.maxBytes});

  void add(Uint8List data) {
    _queue.add(data);
    _size += data.length;
    while (_size > maxBytes && _queue.isNotEmpty) {
      _size -= _queue.first.length;
      _queue.removeFirst();
    }
  }

  /// Remove and return all buffered chunks, clearing the buffer.
  List<Uint8List> drain() {
    final result = _queue.toList();
    _queue.clear();
    _size = 0;
    return result;
  }
}

/// Thrown when audio capture fails.
class AudioCaptureException implements Exception {
  final String message;
  const AudioCaptureException(this.message);

  @override
  String toString() => 'AudioCaptureException: $message';
}
