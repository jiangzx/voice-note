import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/asr_repository.dart';
import '../data/asr_websocket_service.dart';
import '../data/audio_capture_service.dart';

/// Manages ASR WebSocket connection lifecycle, audio streaming, and
/// automatic reconnection with exponential backoff.
class AsrConnectionManager {
  final AsrRepository _asrRepository;

  AsrWebSocketService? _asrService;
  AudioCaptureService? _audioCapture;

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _isConnecting = false;
  bool _disposed = false;

  static const int maxReconnectAttempts = 3;
  static const Duration baseReconnectDelay = Duration(seconds: 1);
  int _reconnectAttempts = 0;

  void Function(String text)? onInterimText;
  void Function(String text)? onFinalText;
  void Function(String message)? onError;
  void Function()? onReconnectFailed;
  void Function(int attempt, int maxAttempts)? onReconnecting;

  /// Return false to suppress reconnection (e.g., not in recognizing state).
  bool Function()? shouldReconnect;

  AsrConnectionManager({required AsrRepository asrRepository})
      : _asrRepository = asrRepository;

  bool get isConnecting => _isConnecting;

  /// Inject shared services (lazily created, not owned by this manager).
  void configure({
    AsrWebSocketService? asrService,
    AudioCaptureService? audioCapture,
  }) {
    _asrService = asrService;
    _audioCapture = audioCapture;
  }

  /// Connect ASR WebSocket, drain pre-buffer, and stream live audio.
  /// Returns true on success, false on failure or guard conditions.
  Future<bool> connectAndStream() async {
    if (_isConnecting) {
      if (kDebugMode) debugPrint('[ASRFlow] Already connecting, skipping');
      return false;
    }
    _isConnecting = true;
    if (kDebugMode) debugPrint('[ASRFlow] Connecting ASR...');

    _cancelSubscriptions();

    try {
      if (kDebugMode) debugPrint('[ASRFlow] Step 1: Fetching token...');
      final tokenResponse = await _asrRepository.getToken();
      if (kDebugMode) {
        debugPrint(
          '[ASRFlow] Step 2: Token OK, wsUrl=${tokenResponse.wsUrl}, '
          'model=${tokenResponse.model}',
        );
      }

      final asr = _asrService;
      if (asr == null || _disposed) {
        if (kDebugMode) {
          debugPrint(
            '[ASRFlow] ABORT: asr=${asr != null}, disposed=$_disposed',
          );
        }
        return false;
      }

      if (kDebugMode) debugPrint('[ASRFlow] Step 3: WebSocket connecting...');
      await asr.connect(
        token: tokenResponse.token,
        wsUrl: tokenResponse.wsUrl,
        model: tokenResponse.model,
      );
      if (kDebugMode) {
        debugPrint(
          '[ASRFlow] Step 4: WebSocket connected, subscribing to events...',
        );
      }

      _subscribeToEvents();
      _reconnectAttempts = 0;

      final preBuffer = _audioCapture?.drainPreBuffer() ?? [];
      if (kDebugMode) {
        debugPrint(
          '[ASRFlow] Step 5: Sending ${preBuffer.length} pre-buffer chunks',
        );
      }
      for (final chunk in preBuffer) {
        asr.sendAudio(chunk);
      }

      final audioStream = _audioCapture?.audioStream;
      if (audioStream != null) {
        if (kDebugMode) {
          debugPrint('[ASRFlow] Step 6: Streaming live audio to ASR');
        }
        _subscriptions.add(
          audioStream.listen((data) => asr.sendAudio(data)),
        );
      } else {
        if (kDebugMode) debugPrint('[ASRFlow] WARNING: audioStream is null!');
      }
      if (kDebugMode) {
        debugPrint('[ASRFlow] ASR connection complete, waiting for events...');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ASRFlow] CONNECTION FAILED: $e');
      _asrRepository.invalidateToken();
      onError?.call('ASR connection failed: $e');
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    await _asrService?.disconnect();
  }

  void commit() {
    _asrService?.commit();
  }

  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }

  void cancelSubscriptions() {
    _cancelSubscriptions();
  }

  void markDisposed() {
    _disposed = true;
  }

  // -- Private --

  void _cancelSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _subscribeToEvents() {
    final asr = _asrService;
    if (asr == null) return;

    _subscriptions.add(
      asr.events.listen((e) {
        if (kDebugMode) {
          debugPrint(
            '[EventDispatch] ASR event: ${e.type}, '
            'text=${e.text}, err=${e.errorMessage}',
          );
        }
      }),
    );

    _subscriptions.add(
      asr.onInterimText.listen((text) {
        if (kDebugMode) debugPrint('[ASRFlow] Interim text: "$text"');
        onInterimText?.call(text);
      }),
    );

    _subscriptions.add(
      asr.onFinalText.listen((text) {
        if (kDebugMode) debugPrint('[ASRFlow] Final text: "$text"');
        onFinalText?.call(text);
      }),
    );

    _subscriptions.add(
      asr.events.where((e) => e.type == AsrEventType.error).listen((e) {
        if (kDebugMode) {
          debugPrint('[ASRFlow] ERROR event: ${e.errorMessage}');
        }
        onError?.call(e.errorMessage ?? 'ASR error');
      }),
    );

    _subscriptions.add(
      asr.events
          .where((e) => e.type == AsrEventType.disconnected)
          .listen((_) => _onDisconnected()),
    );
  }

  Future<void> _onDisconnected() async {
    if (_disposed || !(shouldReconnect?.call() ?? false)) return;

    if (_reconnectAttempts >= maxReconnectAttempts) {
      _reconnectAttempts = 0;
      onReconnectFailed?.call();
      return;
    }

    _reconnectAttempts++;
    final delay = baseReconnectDelay * pow(2, _reconnectAttempts - 1).toInt();
    dev.log(
      'ASR reconnect attempt $_reconnectAttempts/$maxReconnectAttempts '
      'in ${delay.inMilliseconds}ms',
      name: 'AsrConnectionManager',
    );
    onReconnecting?.call(_reconnectAttempts, maxReconnectAttempts);

    await Future<void>.delayed(delay);
    if (_disposed || !(shouldReconnect?.call() ?? false)) return;

    _asrRepository.invalidateToken();
    await connectAndStream();
  }
}
