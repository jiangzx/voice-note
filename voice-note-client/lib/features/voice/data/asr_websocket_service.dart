import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Event types from DashScope ASR WebSocket.
enum AsrEventType {
  sessionCreated,
  sessionUpdated,
  interimText,
  finalText,
  speechStarted,
  speechStopped,
  audioCommitted,
  conversationItemCreated,
  sessionFinished,
  responseCreated,
  responseDone,
  disconnected,
  error,
}

/// An event from the ASR WebSocket.
class AsrEvent {
  final AsrEventType type;
  final String? text;
  final String? sessionId;
  final String? errorMessage;

  const AsrEvent({
    required this.type,
    this.text,
    this.sessionId,
    this.errorMessage,
  });

  @override
  String toString() => 'AsrEvent($type, text=$text, error=$errorMessage)';
}

/// Factory function for creating WebSocket channels (injectable for testing).
typedef WebSocketChannelFactory =
    WebSocketChannel Function(Uri uri, Map<String, String> headers);

/// Default factory using IOWebSocketChannel (supports custom headers).
WebSocketChannel _defaultChannelFactory(Uri uri, Map<String, String> headers) {
  return IOWebSocketChannel.connect(uri, headers: headers);
}

/// Manages DashScope real-time ASR via WebSocket.
///
/// Protocol: DashScope OmniRealtimeConversation API
/// - Manual mode (no server VAD) — client controls speech boundaries.
/// - Audio format: PCM16 16kHz mono, base64 encoded.
/// - Message format: JSON events.
class AsrWebSocketService {
  final WebSocketChannelFactory _channelFactory;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final _eventController = StreamController<AsrEvent>.broadcast();
  bool _isConnected = false;
  String? _sessionId;

  static const String defaultLanguage = 'zh';

  AsrWebSocketService({WebSocketChannelFactory? channelFactory})
    : _channelFactory = channelFactory ?? _defaultChannelFactory;

  bool get isConnected => _isConnected;
  String? get sessionId => _sessionId;

  /// Stream of all ASR events.
  Stream<AsrEvent> get events => _eventController.stream;

  /// Convenience: only interim transcription text.
  Stream<String> get onInterimText => events
      .where((e) => e.type == AsrEventType.interimText && e.text != null)
      .map((e) => e.text!);

  /// Convenience: only final transcription text.
  Stream<String> get onFinalText => events
      .where((e) => e.type == AsrEventType.finalText && e.text != null)
      .map((e) => e.text!);

  /// Connect to DashScope ASR WebSocket and configure session.
  Future<void> connect({
    required String token,
    required String wsUrl,
    required String model,
    String language = defaultLanguage,
  }) async {
    if (_isConnected) {
      dev.log('[ASRFlow] Already connected, disconnecting first', name: 'AsrWebSocket');
      await disconnect();
    }

    try {
      final uri = Uri.parse('$wsUrl?model=$model');
      if (kDebugMode) debugPrint('[ASRFlow] Connecting: $uri');
      final headers = {
        'Authorization': 'Bearer $token',
        'OpenAI-Beta': 'realtime=v1',
      };

      _channel = _channelFactory(uri, headers);
      await _channel!.ready;
      _isConnected = true;
      if (kDebugMode) debugPrint('[ASRFlow] WebSocket READY');

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );

      if (kDebugMode) debugPrint('[ASRFlow] Sending session.update (language=$language)');
      _sendSessionUpdate(language);
    } catch (e) {
      if (kDebugMode) debugPrint('[ASRFlow] Connect FAILED: $e');
      await disconnect();
      rethrow;
    }
  }

  int _audioChunksSent = 0;

  /// Send a chunk of raw PCM16 audio data to ASR.
  void sendAudio(Uint8List pcmData) {
    if (!_isConnected) {
      if (_audioChunksSent == 0) {
        if (kDebugMode) debugPrint('[ASRFlow] sendAudio SKIPPED: not connected');
      }
      return;
    }
    _audioChunksSent++;
    if (_audioChunksSent <= 3 || _audioChunksSent % 50 == 0) {
      if (kDebugMode) debugPrint('[ASRFlow] sendAudio chunk #$_audioChunksSent: ${pcmData.length} bytes');
    }
    _send({
      'event_id': 'evt_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'input_audio_buffer.append',
      'audio': base64Encode(pcmData),
    });
  }

  /// Commit the audio buffer (manual mode — signals end of a speech segment).
  /// DashScope triggers transcription automatically on commit; no explicit
  /// response.create is needed (unsupported by qwen3-asr-flash-realtime).
  void commit() {
    if (!_isConnected) {
      if (kDebugMode) debugPrint('[ASRFlow] commit SKIPPED: not connected');
      return;
    }
    if (kDebugMode) debugPrint('[ASRFlow] Committing audio buffer (sent $_audioChunksSent chunks)');
    _send({
      'event_id': 'evt_commit_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'input_audio_buffer.commit',
    });
    _audioChunksSent = 0;
  }

  /// Finish the session: commit pending audio, then request session end.
  void finish() {
    if (!_isConnected) return;
    commit();
    _send({
      'event_id': 'evt_finish_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'session.finish',
    });
  }

  /// Disconnect from the WebSocket (intentional — suppresses disconnected event).
  Future<void> disconnect() async {
    _isConnected = false; // Set before cancel to suppress _onDone event
    _sessionId = null;
    try {
      await _subscription?.cancel();
    } catch (_) {
      // Best-effort cleanup
    }
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Best-effort cleanup
    }
    _channel = null;
  }

  /// Release all resources.
  Future<void> dispose() async {
    await disconnect();
    try {
      await _eventController.close();
    } catch (_) {
      // Already closed
    }
  }

  // -- Internal protocol handling --

  void _sendSessionUpdate(String language) {
    _send(buildSessionUpdateMessage(language));
  }

  void _send(Map<String, dynamic> message) {
    final type = message['type'];
    if (type != 'input_audio_buffer.append') {
      if (kDebugMode) debugPrint('[ASRFlow] >>> Sending: $type');
    }
    _channel?.sink.add(jsonEncode(message));
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) {
      if (kDebugMode) debugPrint('[EventDispatch] Non-string message: ${raw.runtimeType}');
      _eventController.add(
        const AsrEvent(
          type: AsrEventType.error,
          errorMessage: 'Unexpected non-string WebSocket message',
        ),
      );
      return;
    }
    if (kDebugMode) debugPrint('[EventDispatch] Raw: ${raw.length > 200 ? "${raw.substring(0, 200)}..." : raw}');
    final event = parseEvent(raw);
    if (event.type == AsrEventType.sessionCreated) {
      _sessionId = event.sessionId;
      if (kDebugMode) debugPrint('[EventDispatch] Session created: $_sessionId');
    }
    _eventController.add(event);
  }

  void _onError(dynamic error) {
    if (kDebugMode) debugPrint('[EventDispatch] WebSocket ERROR: $error');
    _eventController.add(
      AsrEvent(
        type: AsrEventType.error,
        errorMessage: 'WebSocket error: $error',
      ),
    );
    _isConnected = false;
  }

  void _onDone() {
    final wasConnected = _isConnected;
    _isConnected = false;
    if (kDebugMode) debugPrint('[EventDispatch] WebSocket DONE (wasConnected=$wasConnected)');
    if (wasConnected) {
      _eventController.add(
        const AsrEvent(
          type: AsrEventType.disconnected,
          errorMessage: 'WebSocket connection closed unexpectedly',
        ),
      );
    }
  }

  // -- Static protocol helpers (testable without connection) --

  /// Build session.update message for manual mode (no server VAD).
  static Map<String, dynamic> buildSessionUpdateMessage(String language) {
    return {
      'event_id': 'evt_session_update',
      'type': 'session.update',
      'session': {
        'modalities': ['text'],
        'input_audio_format': 'pcm',
        'sample_rate': 16000,
        'input_audio_transcription': {'language': language},
        'turn_detection': null,
      },
    };
  }

  /// Build input_audio_buffer.append message.
  static Map<String, dynamic> buildAudioMessage(Uint8List pcmData) {
    return {
      'type': 'input_audio_buffer.append',
      'audio': base64Encode(pcmData),
    };
  }

  /// Parse a raw JSON message from DashScope into an [AsrEvent].
  static AsrEvent parseEvent(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final type = data['type'] as String?;

      return switch (type) {
        'session.created' => AsrEvent(
          type: AsrEventType.sessionCreated,
          sessionId: (data['session'] as Map?)?['id'] as String?,
        ),
        'session.updated' => const AsrEvent(type: AsrEventType.sessionUpdated),
        'conversation.item.input_audio_transcription.text' => AsrEvent(
          type: AsrEventType.interimText,
          text: _nonEmpty(data['text']) ?? _nonEmpty(data['stash']),
        ),
        'conversation.item.input_audio_transcription.completed' => AsrEvent(
          type: AsrEventType.finalText,
          text: data['transcript'] as String? ?? '',
        ),
        'input_audio_buffer.speech_started' => const AsrEvent(
          type: AsrEventType.speechStarted,
        ),
        'input_audio_buffer.speech_stopped' => const AsrEvent(
          type: AsrEventType.speechStopped,
        ),
        'session.finished' => AsrEvent(
          type: AsrEventType.sessionFinished,
          text: data['transcript'] as String?,
        ),
        'input_audio_buffer.committed' => const AsrEvent(
          type: AsrEventType.audioCommitted,
        ),
        'conversation.item.created' => _parseConversationItemCreated(data),
        'response.created' => const AsrEvent(type: AsrEventType.responseCreated),
        'response.done' => const AsrEvent(type: AsrEventType.responseDone),
        'response.audio_transcript.delta' => AsrEvent(
          type: AsrEventType.interimText,
          text: data['delta'] as String? ?? '',
        ),
        'response.audio_transcript.done' => AsrEvent(
          type: AsrEventType.finalText,
          text: data['transcript'] as String? ?? '',
        ),
        'error' => AsrEvent(
          type: AsrEventType.error,
          errorMessage:
              (data['error'] as Map?)?['message'] as String? ??
              'Unknown ASR error',
        ),
        _ => AsrEvent(
          type: AsrEventType.error,
          errorMessage: 'Unrecognized event type: $type',
        ),
      };
    } catch (e) {
      return AsrEvent(
        type: AsrEventType.error,
        errorMessage: 'Failed to parse ASR message: $e',
      );
    }
  }

  static String? _nonEmpty(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }

  static AsrEvent _parseConversationItemCreated(Map<String, dynamic> data) {
    final item = data['item'];
    if (item is! Map<String, dynamic>) {
      return const AsrEvent(type: AsrEventType.conversationItemCreated);
    }

    final content = item['content'];
    if (content is List) {
      for (final part in content) {
        if (part is! Map<String, dynamic>) continue;
        final transcript = part['transcript'] as String?;
        final text = part['text'] as String?;
        final resolvedText = (transcript ?? text)?.trim();
        if (resolvedText != null && resolvedText.isNotEmpty) {
          return AsrEvent(type: AsrEventType.finalText, text: resolvedText);
        }
      }
    }

    return const AsrEvent(type: AsrEventType.conversationItemCreated);
  }
}
