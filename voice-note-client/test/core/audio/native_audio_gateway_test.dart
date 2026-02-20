import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/audio/native_audio_event_validator.dart';
import 'package:suikouji/core/audio/native_audio_gateway.dart';
import 'package:suikouji/core/audio/native_audio_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel('voice_note/native_audio');
  final NativeAudioGateway gateway = NativeAudioGateway();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
      return <Object?, Object?>{
        'ok': true,
        'method': methodCall.method,
        'args': methodCall.arguments,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  test('playTts serializes required fields with requestId', () async {
    final result = await gateway.playTts(
      sessionId: 'sess1',
      requestId: 'req1',
      text: '你好',
      interruptible: false,
      speechRate: 1.2,
    );

    final args = result['args'] as Map<Object?, Object?>;
    expect(result['method'], 'playTts');
    expect(args['sessionId'], 'sess1');
    expect(args['requestId'], 'req1');
    expect(args['text'], '你好');
    expect(args['interruptible'], false);
    expect(args['speechRate'], 1.2);
  });

  test('setAsrMuted serializes muted and reason', () async {
    final result = await gateway.setAsrMuted(
      sessionId: 'sess2',
      muted: true,
      reason: 'tts_playback',
    );

    final args = result['args'] as Map<Object?, Object?>;
    expect(result['method'], 'setAsrMuted');
    expect(args['sessionId'], 'sess2');
    expect(args['muted'], true);
    expect(args['reason'], 'tts_playback');
  });

  test('native event deserialization keeps standard fields', () {
    final event = NativeAudioEvent.fromMap(const <Object?, Object?>{
      'event': 'bargeInCompleted',
      'sessionId': 'sess3',
      'requestId': 'req3',
      'timestamp': 123456789,
      'data': <Object?, Object?>{
        'route': 'speaker',
        'focusState': 'gain',
        'canAutoResume': false,
      },
    });

    expect(event.event, 'bargeInCompleted');
    expect(event.sessionId, 'sess3');
    expect(event.requestId, 'req3');
    expect(event.timestamp, 123456789);
    expect(event.route, 'speaker');
    expect(event.focusState, 'gain');
    expect(event.canAutoResume, false);
  });

  test('native error mapping normalizes platform rawCode', () {
    final event = NativeAudioEvent.fromMap(const <Object?, Object?>{
      'event': 'runtimeError',
      'sessionId': 'sess4',
      'timestamp': 123,
      'data': <Object?, Object?>{},
      'error': <Object?, Object?>{
        'code': 'tts_error',
        'message': 'engine failed',
        'rawCode': 'tts_error_5',
      },
    });

    expect(event.error, isNotNull);
    expect(event.error!.code, NativeAudioError.codeTtsFailed);
    expect(event.error!.rawCode, 'tts_error_5');
  });

  test('event validator accepts valid route change payload', () {
    final result = NativeAudioEventValidator.validate(const <Object?, Object?>{
      'event': 'audioRouteChanged',
      'sessionId': 'sess5',
      'timestamp': 123,
      'data': <Object?, Object?>{
        'oldRoute': 'speaker',
        'newRoute': 'bluetooth',
        'reason': 'new_device_available',
      },
    });

    expect(result.valid, true);
  });

  test('event validator rejects missing required fields', () {
    final result = NativeAudioEventValidator.validate(const <Object?, Object?>{
      'event': 'audioRouteChanged',
      'sessionId': 'sess5',
      'timestamp': 123,
      'data': <Object?, Object?>{
        'oldRoute': 'speaker',
      },
    });

    expect(result.valid, false);
    expect(result.message, contains('newRoute'));
  });
}
