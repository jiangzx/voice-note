import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/category/domain/services/time_period_recommendation_service.dart';

void main() {
  const service = TimePeriodRecommendationService();

  group('TimePeriodRecommendationService', () {
    test('returns 餐饮 for breakfast time (07:30)', () {
      final result = service.getRecommendedCategoryNames(
        DateTime(2026, 2, 16, 7, 30),
      );
      expect(result, contains('餐饮'));
    });

    test('returns 餐饮 for lunch time (12:00)', () {
      final result = service.getRecommendedCategoryNames(
        DateTime(2026, 2, 16, 12, 0),
      );
      expect(result, contains('餐饮'));
    });

    test('returns 餐饮 and 交通 for evening rush (18:00)', () {
      final result = service.getRecommendedCategoryNames(
        DateTime(2026, 2, 16, 18, 0),
      );
      expect(result, contains('餐饮'));
      expect(result, contains('交通'));
    });

    test('returns 交通 for morning commute (08:00)', () {
      final result = service.getRecommendedCategoryNames(
        DateTime(2026, 2, 16, 8, 0),
      );
      expect(result, contains('交通'));
    });

    test('returns empty list outside any time period (03:00)', () {
      final result = service.getRecommendedCategoryNames(
        DateTime(2026, 2, 16, 3, 0),
      );
      expect(result, isEmpty);
    });

    test('returns empty list at boundary gap (10:00)', () {
      final result = service.getRecommendedCategoryNames(
        DateTime(2026, 2, 16, 10, 0),
      );
      expect(result, isEmpty);
    });
  });
}
