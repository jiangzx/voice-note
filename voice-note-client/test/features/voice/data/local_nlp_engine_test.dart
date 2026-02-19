import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/data/local_nlp_engine.dart';

void main() {
  final now = DateTime(2026, 2, 17);

  group('LocalNlpEngine', () {
    late LocalNlpEngine engine;

    setUp(() {
      engine = LocalNlpEngine();
    });

    test('parses complete input: 昨天打车花了28块5', () {
      final result = engine.parse('昨天打车花了28块5', now: now);

      expect(result.amount, 28.5);
      expect(result.date, '2026-02-16');
      expect(result.category, '交通');
      expect(result.type, 'EXPENSE');
      expect(result.isComplete, isTrue);
    });

    test('parses partial input: 午饭35', () {
      final result = engine.parse('午饭35', now: now);

      expect(result.amount, 35.0);
      expect(result.category, '餐饮');
      expect(result.type, 'EXPENSE');
      expect(result.date, isNull);
      expect(result.isComplete, isTrue);
    });

    test('parses income: 发工资了8000', () {
      final result = engine.parse('发工资了8000', now: now);

      expect(result.amount, 8000.0);
      expect(result.category, '工资');
      expect(result.type, 'INCOME');
      expect(result.isComplete, isTrue);
    });

    test('incomplete parse when no category match', () {
      final result = engine.parse('花了100', now: now);

      expect(result.amount, 100.0);
      expect(result.category, isNull);
      expect(result.isComplete, isFalse);
    });

    test('incomplete parse when no amount', () {
      final result = engine.parse('打车', now: now);

      expect(result.amount, isNull);
      expect(result.category, '交通');
      expect(result.isComplete, isFalse);
    });

    test('custom categories are used', () {
      final customEngine = LocalNlpEngine(customCategories: ['学习资料']);
      final result = customEngine.parse('买了学习资料50', now: now);

      expect(result.category, '学习资料');
      expect(result.amount, 50.0);
      expect(result.isComplete, isTrue);
    });

    test('transfer type detected', () {
      final result = engine.parse('转账给小明500', now: now);

      expect(result.type, 'TRANSFER');
      expect(result.amount, 500.0);
    });

    test('empty string returns incomplete result', () {
      final result = engine.parse('', now: now);

      expect(result.isComplete, isFalse);
      expect(result.amount, isNull);
      expect(result.category, isNull);
    });

    test('whitespace-only string returns incomplete result', () {
      final result = engine.parse('   ', now: now);

      expect(result.isComplete, isFalse);
      expect(result.amount, isNull);
    });

    test('very long input is truncated and parsed without error', () {
      final longInput = '咖啡28块' * 100; // 400+ chars
      final result = engine.parse(longInput, now: now);

      expect(result.amount, isNotNull);
      expect(result.isComplete, isA<bool>());
    });
  });
}
