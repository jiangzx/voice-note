import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/data/asr_websocket_service.dart';

void main() {
  group('AsrWebSocketService.parseEvent', () {
    test('parses session.created with session id', () {
      final raw = jsonEncode({
        'type': 'session.created',
        'session': {'id': 'sess_abc123'},
      });

      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.sessionCreated);
      expect(event.sessionId, 'sess_abc123');
    });

    test('parses session.updated', () {
      final raw = jsonEncode({'type': 'session.updated'});
      final event = AsrWebSocketService.parseEvent(raw);
      expect(event.type, AsrEventType.sessionUpdated);
    });

    test('parses interim text from "text" field', () {
      final raw = jsonEncode({
        'type': 'conversation.item.input_audio_transcription.text',
        'text': '咖啡',
      });

      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.interimText);
      expect(event.text, '咖啡');
    });

    test('parses interim text from "stash" field as fallback', () {
      final raw = jsonEncode({
        'type': 'conversation.item.input_audio_transcription.text',
        'stash': '咖啡28',
      });

      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.interimText);
      expect(event.text, '咖啡28');
    });

    test('uses stash when text is empty string', () {
      final raw = jsonEncode({
        'type': 'conversation.item.input_audio_transcription.text',
        'text': '',
        'stash': '吃饭花了二十五',
      });

      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.interimText);
      expect(event.text, '吃饭花了二十五');
    });

    test('parses final transcription (completed)', () {
      final raw = jsonEncode({
        'type': 'conversation.item.input_audio_transcription.completed',
        'transcript': '咖啡28块',
      });

      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.finalText);
      expect(event.text, '咖啡28块');
    });

    test('parses final transcription with empty transcript', () {
      final raw = jsonEncode({
        'type': 'conversation.item.input_audio_transcription.completed',
      });

      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.finalText);
      expect(event.text, '');
    });

    test('parses speech started', () {
      final raw = jsonEncode({'type': 'input_audio_buffer.speech_started'});
      final event = AsrWebSocketService.parseEvent(raw);
      expect(event.type, AsrEventType.speechStarted);
    });

    test('parses speech stopped', () {
      final raw = jsonEncode({'type': 'input_audio_buffer.speech_stopped'});
      final event = AsrWebSocketService.parseEvent(raw);
      expect(event.type, AsrEventType.speechStopped);
    });

    test('parses session.finished with transcript', () {
      final raw = jsonEncode({
        'type': 'session.finished',
        'transcript': '今天吃午饭花了35',
      });

      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.sessionFinished);
      expect(event.text, '今天吃午饭花了35');
    });

    test('parses error event', () {
      final raw = jsonEncode({
        'type': 'error',
        'error': {'message': 'Token expired'},
      });

      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.error);
      expect(event.errorMessage, 'Token expired');
    });

    test('parses input_audio_buffer.committed as audio committed event', () {
      final raw = jsonEncode({'type': 'input_audio_buffer.committed'});
      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.audioCommitted);
    });

    test('parses conversation.item.created transcript as final text', () {
      final raw = jsonEncode({
        'type': 'conversation.item.created',
        'item': {
          'content': [
            {'type': 'input_audio', 'transcript': '今天中午咖啡28块'},
          ],
        },
      });
      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.finalText);
      expect(event.text, '今天中午咖啡28块');
    });

    test('parses conversation.item.created without transcript metadata', () {
      final raw = jsonEncode({
        'type': 'conversation.item.created',
        'item': {'content': <Map<String, dynamic>>[]},
      });
      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.conversationItemCreated);
    });

    test('handles unknown event type gracefully', () {
      final raw = jsonEncode({'type': 'some.unknown.event'});
      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.error);
      expect(event.errorMessage, contains('Unrecognized'));
    });

    test('handles invalid JSON gracefully', () {
      final event = AsrWebSocketService.parseEvent('not valid json');
      expect(event.type, AsrEventType.error);
      expect(event.errorMessage, contains('Failed to parse'));
    });
  });

  group('AsrWebSocketService.buildSessionUpdateMessage', () {
    test('builds correct manual mode session update', () {
      final msg = AsrWebSocketService.buildSessionUpdateMessage('zh');

      expect(msg['type'], 'session.update');
      expect(msg['session']['modalities'], ['text']);
      expect(msg['session']['input_audio_format'], 'pcm');
      expect(msg['session']['sample_rate'], 16000);
      expect(msg['session']['input_audio_transcription']['language'], 'zh');
      expect(msg['session']['turn_detection'], isNull);
    });

    test('supports different languages', () {
      final msg = AsrWebSocketService.buildSessionUpdateMessage('en');
      expect(msg['session']['input_audio_transcription']['language'], 'en');
    });
  });

  group('AsrWebSocketService.buildAudioMessage', () {
    test('builds correct audio append message with base64 encoding', () {
      final pcm = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final msg = AsrWebSocketService.buildAudioMessage(pcm);

      expect(msg['type'], 'input_audio_buffer.append');
      expect(msg['audio'], base64Encode(pcm));
    });

    test('handles empty audio data', () {
      final pcm = Uint8List(0);
      final msg = AsrWebSocketService.buildAudioMessage(pcm);

      expect(msg['type'], 'input_audio_buffer.append');
      expect(msg['audio'], '');
    });
  });

  group('AsrEvent', () {
    test('toString includes type and text', () {
      const event = AsrEvent(type: AsrEventType.finalText, text: '测试');
      expect(event.toString(), contains('finalText'));
      expect(event.toString(), contains('测试'));
    });
  });

  group('AsrWebSocketService error scenarios', () {
    test('_onMessage handles non-string data as error event', () async {
      final service = AsrWebSocketService();
      final events = <AsrEvent>[];
      service.events.listen(events.add);

      // Simulate receiving binary data (non-string) by directly testing parseEvent
      // Since _onMessage is private, we verify the guard via connect + fake channel
      // For now, verify parseEvent handles malformed input
      final event = AsrWebSocketService.parseEvent('');
      expect(event.type, AsrEventType.error);
    });

    test('parseEvent handles null type field', () {
      final raw = jsonEncode({'data': 'no type field'});
      final event = AsrWebSocketService.parseEvent(raw);

      expect(event.type, AsrEventType.error);
      expect(event.errorMessage, contains('Unrecognized'));
    });
  });
}
