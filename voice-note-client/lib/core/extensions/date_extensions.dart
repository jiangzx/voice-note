/// Convenience extensions on [DateTime].
extension DateExtensions on DateTime {
  /// Strips time components, returning midnight of the same date.
  DateTime get toDateOnly => DateTime(year, month, day);

  /// Whether this date falls on the same calendar day as [other].
  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  /// Whether this date falls in the same month as [other].
  bool isSameMonth(DateTime other) =>
      year == other.year && month == other.month;

  /// Whether this date is in the same ISO week (Mon–Sun) as [other].
  bool isSameWeek(DateTime other) {
    final thisMonday = subtract(Duration(days: weekday - 1));
    final otherMonday = other.subtract(Duration(days: other.weekday - 1));
    return thisMonday.year == otherMonday.year &&
        thisMonday.month == otherMonday.month &&
        thisMonday.day == otherMonday.day;
  }

  /// Yesterday relative to this date.
  DateTime get yesterday => subtract(const Duration(days: 1)).toDateOnly;

  /// The day before yesterday relative to this date.
  DateTime get dayBeforeYesterday =>
      subtract(const Duration(days: 2)).toDateOnly;
}

/// Common date range shortcuts based on the current date.
class DateRanges {
  DateRanges._();

  /// Today: [start of today, end of today].
  static ({DateTime from, DateTime to}) today() {
    final now = DateTime.now();
    return (
      from: DateTime(now.year, now.month, now.day),
      to: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  /// This week: [Monday, Sunday] of the current week.
  static ({DateTime from, DateTime to}) thisWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return (
      from: DateTime(monday.year, monday.month, monday.day),
      to: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59),
    );
  }

  /// This month: [first day, last day] of the current month.
  static ({DateTime from, DateTime to}) thisMonth() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return (
      from: DateTime(now.year, now.month, 1),
      to: DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59, 59),
    );
  }

  /// This year: [Jan 1, Dec 31] of the current year.
  static ({DateTime from, DateTime to}) thisYear() {
    final year = DateTime.now().year;
    return (from: DateTime(year), to: DateTime(year, 12, 31, 23, 59, 59));
  }
}
