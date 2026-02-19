import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/design_tokens.dart';

void main() {
  group('AppSpacing', () {
    test('values are multiples of 4', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.xxl, 32);
    });

    test('values are in ascending order', () {
      final values = [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ];
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });
  });

  group('AppRadius', () {
    test('values are in ascending order', () {
      final values = [AppRadius.sm, AppRadius.md, AppRadius.lg, AppRadius.xl];
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });
  });

  group('AppDuration', () {
    test('values are in ascending order', () {
      expect(AppDuration.fast.inMilliseconds, 150);
      expect(AppDuration.normal.inMilliseconds, 300);
      expect(AppDuration.slow.inMilliseconds, 450);
      expect(
        AppDuration.normal.inMilliseconds,
        greaterThan(AppDuration.fast.inMilliseconds),
      );
    });
  });
}
