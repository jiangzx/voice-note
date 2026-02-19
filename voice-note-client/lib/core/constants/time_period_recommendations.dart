/// Time-period → category recommendation mappings.
/// Defined in constants for easy future adjustment.
class TimePeriodRecommendation {
  final String label;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String categoryName;
  final String categoryType;

  const TimePeriodRecommendation({
    required this.label,
    required this.startHour,
    this.startMinute = 0,
    required this.endHour,
    this.endMinute = 0,
    required this.categoryName,
    this.categoryType = 'expense',
  });

  bool matchesTime(int hour, int minute) {
    final current = hour * 60 + minute;
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    return current >= start && current <= end;
  }
}

const timePeriodRecommendations = <TimePeriodRecommendation>[
  TimePeriodRecommendation(
    label: '早餐',
    startHour: 6,
    endHour: 9,
    categoryName: '餐饮',
  ),
  TimePeriodRecommendation(
    label: '午餐',
    startHour: 11,
    endHour: 13,
    categoryName: '餐饮',
  ),
  TimePeriodRecommendation(
    label: '晚餐',
    startHour: 17,
    endHour: 19,
    endMinute: 30,
    categoryName: '餐饮',
  ),
  TimePeriodRecommendation(
    label: '早通勤',
    startHour: 7,
    endHour: 9,
    categoryName: '交通',
  ),
  TimePeriodRecommendation(
    label: '晚通勤',
    startHour: 17,
    endHour: 19,
    categoryName: '交通',
  ),
];
