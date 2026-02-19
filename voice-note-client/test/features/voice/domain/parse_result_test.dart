import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';

void main() {
  group('ParseResult', () {
    test('isComplete when amount and category present', () {
      const result = ParseResult(
        amount: 35,
        category: '餐饮',
        source: ParseSource.local,
      );
      expect(result.isComplete, isTrue);
    });

    test('not complete when amount missing', () {
      const result = ParseResult(
        category: '餐饮',
        source: ParseSource.local,
      );
      expect(result.isComplete, isFalse);
    });

    test('not complete when category missing', () {
      const result = ParseResult(
        amount: 35,
        source: ParseSource.local,
      );
      expect(result.isComplete, isFalse);
    });

    test('copyWith updates specific fields', () {
      const original = ParseResult(
        amount: 35,
        category: '餐饮',
        type: 'EXPENSE',
        confidence: 0.9,
        source: ParseSource.local,
      );

      final updated = original.copyWith(amount: 45, category: '交通');

      expect(updated.amount, 45);
      expect(updated.category, '交通');
      expect(updated.type, 'EXPENSE');
      expect(updated.confidence, 0.9);
      expect(updated.source, ParseSource.local);
    });
  });
}
