import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/data/nlp/date_extractor.dart';

void main() {
  // Fixed reference date: Tuesday, Feb 17, 2026
  final now = DateTime(2026, 2, 17);

  group('DateExtractor', () {
    test('extracts 今天', () {
      final result = DateExtractor.extract('今天午饭35', now: now);
      expect(result, DateTime(2026, 2, 17));
    });

    test('extracts 昨天', () {
      final result = DateExtractor.extract('昨天打车28', now: now);
      expect(result, DateTime(2026, 2, 16));
    });

    test('extracts 前天', () {
      final result = DateExtractor.extract('前天买了本书', now: now);
      expect(result, DateTime(2026, 2, 15));
    });

    test('extracts 上周三 (Feb 17 is Tuesday → last Wed = Feb 11)', () {
      final result = DateExtractor.extract('上周三打车', now: now);
      expect(result, DateTime(2026, 2, 11));
    });

    test('extracts absolute date 2月15号', () {
      final result = DateExtractor.extract('2月15号吃饭', now: now);
      expect(result, DateTime(2026, 2, 15));
    });

    test('extracts absolute date with year 2026年1月5日', () {
      final result = DateExtractor.extract('2026年1月5日聚餐', now: now);
      expect(result, DateTime(2026, 1, 5));
    });

    test('returns null for no date', () {
      final result = DateExtractor.extract('午饭35', now: now);
      expect(result, isNull);
    });

    test('extracts 周一 as most recent Monday', () {
      // Feb 17 is Tuesday, so most recent Monday = Feb 16
      final result = DateExtractor.extract('周一开会', now: now);
      expect(result, DateTime(2026, 2, 16));
    });
  });
}
