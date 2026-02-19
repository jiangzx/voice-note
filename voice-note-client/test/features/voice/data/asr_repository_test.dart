import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/network/dto/asr_token_response.dart';

void main() {
  group('AsrTokenResponse caching logic', () {
    test('isValid returns true for future token', () {
      final futureTs = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 300;
      final token = AsrTokenResponse(
        token: 'st-test',
        expiresAt: futureTs,
        model: 'qwen3-asr-flash-realtime',
        wsUrl: 'wss://test',
      );

      expect(token.isValid, isTrue);
    });

    test('isValid returns false for expired token', () {
      const token = AsrTokenResponse(
        token: 'st-expired',
        expiresAt: 1000,
        model: 'test',
        wsUrl: 'wss://test',
      );

      expect(token.isValid, isFalse);
    });

    test('isValid returns false when within 30s safety margin', () {
      final almostExpired = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 20;
      final token = AsrTokenResponse(
        token: 'st-almost',
        expiresAt: almostExpired,
        model: 'test',
        wsUrl: 'wss://test',
      );

      expect(token.isValid, isFalse);
    });
  });
}
