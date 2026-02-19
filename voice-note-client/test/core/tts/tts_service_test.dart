import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suikouji/core/tts/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TtsService service;

  /// Mock flutter_tts method channel to simulate the native TTS engine.
  void mockTtsPlatformChannel() {
    const channel = MethodChannel('flutter_tts');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'setLanguage':
        case 'setSpeechRate':
        case 'setVolume':
        case 'isLanguageAvailable':
          return 1; // success
        case 'speak':
          // Simulate async completion via completion handler
          Future.microtask(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .handlePlatformMessage(
              channel.name,
              channel.codec.encodeMethodCall(
                const MethodCall('speak.onComplete', 'tts1'),
              ),
              (_) {},
            );
          });
          return 1;
        case 'stop':
          return 1;
        case 'getLanguages':
          return ['zh-CN', 'en-US'];
        case 'getEngines':
          return ['com.google.android.tts'];
        case 'isLanguageInstalled':
          return 1;
        case 'awaitSpeakCompletion':
          return 1;
        case 'getMaxSpeechInputLength':
          return 4000;
        case 'setSharedInstance':
          return 1;
        default:
          return null;
      }
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    mockTtsPlatformChannel();
    service = TtsService(prefs: prefs);
  });

  tearDown(() async {
    await service.dispose();
  });

  group('TtsService', () {
    test('init sets available=true when engine works', () async {
      await service.init();
      expect(service.available, isTrue);
    });

    test('default enabled is true', () async {
      await service.init();
      expect(service.enabled, isTrue);
    });

    test('default speechRate is 1.0', () async {
      await service.init();
      expect(service.speechRate, 1.0);
    });

    test('reads persisted enabled from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'tts_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      mockTtsPlatformChannel();
      final svc = TtsService(prefs: prefs);
      await svc.init();
      expect(svc.enabled, isTrue);
      await svc.dispose();
    });

    test('reads persisted speechRate from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'tts_speed': 1.5});
      final prefs = await SharedPreferences.getInstance();
      mockTtsPlatformChannel();
      final svc = TtsService(prefs: prefs);
      await svc.init();
      expect(svc.speechRate, 1.5);
      await svc.dispose();
    });

    test('setEnabled persists value', () async {
      await service.init();
      await service.setEnabled(true);
      expect(service.enabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tts_enabled'), isTrue);
    });

    test('setSpeechRate clamps and persists', () async {
      await service.init();
      await service.setSpeechRate(3.0);
      expect(service.speechRate, 2.0);

      await service.setSpeechRate(0.1);
      expect(service.speechRate, 0.5);

      await service.setSpeechRate(1.2);
      expect(service.speechRate, 1.2);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('tts_speed'), 1.2);
    });

    test('speak is silent when disabled', () async {
      await service.init();
      await service.setEnabled(false);
      await service.speak('hello');
      expect(service.isSpeaking, isFalse);
    });

    test('speak is silent when unavailable', () async {
      // Don't call init → available remains false
      service = TtsService(
        prefs: await SharedPreferences.getInstance(),
      );
      await service.setEnabled(true);
      await service.speak('hello');
      expect(service.isSpeaking, isFalse);
    });

    test('speak is silent for empty text', () async {
      await service.init();
      await service.setEnabled(true);
      await service.speak('');
      expect(service.isSpeaking, isFalse);
    });

    test('setEnabled(false) stops ongoing speech', () async {
      await service.init();
      await service.setEnabled(true);
      // Start speaking in background
      final speakFuture = service.speak('test');
      await service.setEnabled(false);
      await speakFuture;
      expect(service.isSpeaking, isFalse);
    });
  });
}
