import '../../../../core/constants/time_period_recommendations.dart';

/// Returns recommended category names based on current time.
class TimePeriodRecommendationService {
  const TimePeriodRecommendationService();

  /// Returns distinct category names that match the given [time].
  List<String> getRecommendedCategoryNames(DateTime time) {
    final hour = time.hour;
    final minute = time.minute;
    final matched = <String>{};
    for (final rec in timePeriodRecommendations) {
      if (rec.matchesTime(hour, minute)) {
        matched.add(rec.categoryName);
      }
    }
    return matched.toList();
  }
}
