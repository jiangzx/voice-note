/// Extracts dates from Chinese natural language text.
class DateExtractor {
  static final _relativeDates = {
    '今天': 0,
    '今日': 0,
    '昨天': -1,
    '昨日': -1,
    '前天': -2,
    '前日': -2,
    '大前天': -3,
  };

  static final _weekdays = {
    '周一': DateTime.monday,
    '星期一': DateTime.monday,
    '周二': DateTime.tuesday,
    '星期二': DateTime.tuesday,
    '周三': DateTime.wednesday,
    '星期三': DateTime.wednesday,
    '周四': DateTime.thursday,
    '星期四': DateTime.thursday,
    '周五': DateTime.friday,
    '星期五': DateTime.friday,
    '周六': DateTime.saturday,
    '星期六': DateTime.saturday,
    '周日': DateTime.sunday,
    '周天': DateTime.sunday,
    '星期天': DateTime.sunday,
    '星期日': DateTime.sunday,
  };

  // Matches: 2月15号, 2月15日, 02-15, 2026年2月15日
  static final _absoluteDate = RegExp(
    r'(?:(\d{4})年)?(\d{1,2})月(\d{1,2})[日号]?',
  );

  // Matches: 上周三, 上星期五
  static final _lastWeekday = RegExp(
    r'上(周[一二三四五六日天]|星期[一二三四五六日天])',
  );

  // Matches: 这周三, 这星期五
  static final _thisWeekday = RegExp(
    r'这(周[一二三四五六日天]|星期[一二三四五六日天])',
  );

  /// Extract the date from [text], or null if none found.
  /// [now] can be injected for testing.
  static DateTime? extract(String text, {DateTime? now}) {
    final today = now ?? DateTime.now();

    // 1. Check relative dates (今天/昨天/前天)
    for (final entry in _relativeDates.entries) {
      if (text.contains(entry.key)) {
        return _dateOnly(today.add(Duration(days: entry.value)));
      }
    }

    // 2. Check "上周X"
    final lastWeekMatch = _lastWeekday.firstMatch(text);
    if (lastWeekMatch != null) {
      final weekdayStr = lastWeekMatch.group(1)!;
      final targetDay = _weekdays[weekdayStr];
      if (targetDay != null) {
        return _findWeekday(today, targetDay, previous: true);
      }
    }

    // 3. Check "这周X"
    final thisWeekMatch = _thisWeekday.firstMatch(text);
    if (thisWeekMatch != null) {
      final weekdayStr = thisWeekMatch.group(1)!;
      final targetDay = _weekdays[weekdayStr];
      if (targetDay != null) {
        return _findWeekday(today, targetDay, previous: false);
      }
    }

    // 4. Check bare weekday references (周三 → most recent past)
    for (final entry in _weekdays.entries) {
      if (text.contains(entry.key)) {
        return _findWeekday(today, entry.value, previous: true);
      }
    }

    // 5. Check absolute dates (2月15号, 2026年2月15日)
    final absMatch = _absoluteDate.firstMatch(text);
    if (absMatch != null) {
      final year = absMatch.group(1) != null
          ? int.parse(absMatch.group(1)!)
          : today.year;
      final month = int.parse(absMatch.group(2)!);
      final day = int.parse(absMatch.group(3)!);
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime _findWeekday(DateTime from, int targetDay, {required bool previous}) {
    final today = _dateOnly(from);
    if (previous) {
      // Go back to find the most recent target weekday (at least 1 day ago)
      var d = today.subtract(const Duration(days: 1));
      while (d.weekday != targetDay) {
        d = d.subtract(const Duration(days: 1));
      }
      return d;
    } else {
      // Find this week's target weekday
      final diff = targetDay - today.weekday;
      return today.add(Duration(days: diff));
    }
  }
}
