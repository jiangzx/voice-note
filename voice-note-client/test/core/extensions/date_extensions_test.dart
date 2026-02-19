import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/extensions/date_extensions.dart';

void main() {
  group('DateExtensions', () {
    test('toDateOnly strips time', () {
      final dt = DateTime(2026, 2, 16, 14, 30, 45);
      expect(dt.toDateOnly, DateTime(2026, 2, 16));
    });

    test('isSameDay returns true for same day', () {
      final a = DateTime(2026, 2, 16, 10);
      final b = DateTime(2026, 2, 16, 22);
      expect(a.isSameDay(b), isTrue);
    });

    test('isSameDay returns false for different day', () {
      final a = DateTime(2026, 2, 16);
      final b = DateTime(2026, 2, 17);
      expect(a.isSameDay(b), isFalse);
    });

    test('isSameMonth returns true for same month', () {
      final a = DateTime(2026, 2, 1);
      final b = DateTime(2026, 2, 28);
      expect(a.isSameMonth(b), isTrue);
    });

    test('isSameMonth returns false for different month', () {
      final a = DateTime(2026, 2, 28);
      final b = DateTime(2026, 3, 1);
      expect(a.isSameMonth(b), isFalse);
    });

    test('yesterday returns previous day', () {
      final dt = DateTime(2026, 2, 16, 14, 30);
      expect(dt.yesterday, DateTime(2026, 2, 15));
    });

    test('dayBeforeYesterday returns two days ago', () {
      final dt = DateTime(2026, 2, 16, 14, 30);
      expect(dt.dayBeforeYesterday, DateTime(2026, 2, 14));
    });
  });

  group('DateRanges', () {
    test('today returns start and end of current day', () {
      final range = DateRanges.today();
      expect(range.from.hour, 0);
      expect(range.to.hour, 23);
      expect(range.from.day, range.to.day);
    });

    test('thisMonth starts on day 1', () {
      final range = DateRanges.thisMonth();
      expect(range.from.day, 1);
    });

    test('thisYear starts Jan 1 and ends Dec 31', () {
      final range = DateRanges.thisYear();
      expect(range.from.month, 1);
      expect(range.from.day, 1);
      expect(range.to.month, 12);
      expect(range.to.day, 31);
    });
  });
}
