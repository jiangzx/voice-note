import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/data/audio_capture_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock the record package's method channel.
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'create':
        case 'stop':
        case 'dispose':
          return null;
        case 'hasPermission':
          return false;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  group('AudioCaptureService constants', () {
    test('sample rate is 16kHz', () {
      expect(AudioCaptureService.sampleRate, 16000);
    });

    test('mono channel', () {
      expect(AudioCaptureService.numChannels, 1);
    });

    test('bytes per ms matches PCM16 16kHz mono', () {
      // 16kHz * 16bit / 8 * 1 channel = 32000 bytes/sec = 32 bytes/ms
      expect(AudioCaptureService.bytesPerMs, 32);
    });
  });

  group('AudioCaptureService initial state', () {
    test('is not capturing initially', () async {
      final service = AudioCaptureService();
      // Allow the async AudioRecorder.create() to settle
      await Future<void>.delayed(Duration.zero);

      expect(service.isCapturing, isFalse);
    });

    test('audio stream is null initially', () async {
      final service = AudioCaptureService();
      await Future<void>.delayed(Duration.zero);

      expect(service.audioStream, isNull);
    });

    test('drainPreBuffer returns empty list initially', () async {
      final service = AudioCaptureService();
      await Future<void>.delayed(Duration.zero);

      expect(service.drainPreBuffer(), isEmpty);
    });
  });

  group('AudioCaptureException', () {
    test('toString includes message', () {
      const ex = AudioCaptureException('test error');
      expect(ex.toString(), contains('test error'));
      expect(ex.message, 'test error');
    });
  });
}
