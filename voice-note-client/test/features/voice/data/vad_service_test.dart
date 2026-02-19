import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/data/vad_service.dart';

void main() {
  group('VadService configuration', () {
    test('has sensible defaults', () {
      final service = VadService();

      expect(service.positiveSpeechThreshold, 0.5);
      expect(service.negativeSpeechThreshold, 0.35);
      expect(service.preSpeechPadFrames, 3);
      expect(service.redemptionFrames, 8);
      expect(service.minSpeechFrames, 3);
      expect(service.isListening, isFalse);
    });

    test('accepts custom thresholds', () {
      final service = VadService(
        positiveSpeechThreshold: 0.6,
        negativeSpeechThreshold: 0.4,
        preSpeechPadFrames: 5,
        redemptionFrames: 12,
        minSpeechFrames: 5,
      );

      expect(service.positiveSpeechThreshold, 0.6);
      expect(service.negativeSpeechThreshold, 0.4);
      expect(service.preSpeechPadFrames, 5);
      expect(service.redemptionFrames, 12);
      expect(service.minSpeechFrames, 5);
    });
  });

  group('VadFrameData typedef', () {
    test('can create frame data record', () {
      final VadFrameData data = (
        isSpeech: 0.92,
        notSpeech: 0.08,
        frame: [0.1, 0.2, 0.3],
      );

      expect(data.isSpeech, 0.92);
      expect(data.notSpeech, 0.08);
      expect(data.frame, hasLength(3));
    });
  });
}
