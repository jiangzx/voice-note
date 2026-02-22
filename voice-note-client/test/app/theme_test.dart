import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';

void main() {
  group('buildTheme', () {
    test('produces light theme with correct brightness', () {
      final theme = buildTheme(Colors.teal, Brightness.light);
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
    });

    test('produces dark theme with correct brightness', () {
      final theme = buildTheme(Colors.teal, Brightness.dark);
      expect(theme.brightness, Brightness.dark);
    });

    test('light theme has TransactionColors extension', () {
      final theme = buildTheme(Colors.teal, Brightness.light);
      final colors = theme.extension<TransactionColors>();
      expect(colors, isNotNull);
      expect(colors!.income, isA<Color>());
      expect(colors.expense, isA<Color>());
      expect(colors.transfer, isA<Color>());
    });

    test('dark theme has TransactionColors extension', () {
      final theme = buildTheme(Colors.teal, Brightness.dark);
      final colors = theme.extension<TransactionColors>();
      expect(colors, isNotNull);
      expect(colors!.income, isA<Color>());
      expect(colors.expense, isA<Color>());
      expect(colors.transfer, isA<Color>());
    });

    test('uses provided seed color', () {
      final tealTheme = buildTheme(Colors.teal, Brightness.light);
      final indigoTheme = buildTheme(Colors.indigo, Brightness.light);
      expect(
        tealTheme.colorScheme.primary,
        isNot(equals(indigoTheme.colorScheme.primary)),
      );
    });
  });

  group('AppThemeColors', () {
    test('has at least 5 presets', () {
      expect(AppThemeColors.presets.length, greaterThanOrEqualTo(5));
    });

    test('presetNames matches presets length', () {
      expect(
        AppThemeColors.presetNames.length,
        equals(AppThemeColors.presets.length),
      );
    });
  });

  group('TransactionColors', () {
    test('copyWith replaces values', () {
      const original = TransactionColors(
        income: Colors.green,
        expense: Colors.red,
        transfer: Colors.blue,
      );
      final updated = original.copyWith(income: Colors.yellow);
      expect(updated.income, Colors.yellow);
      expect(updated.expense, Colors.red);
    });

    test('lerp interpolates between colors', () {
      const a = TransactionColors(
        income: Colors.black,
        expense: Colors.black,
        transfer: Colors.black,
      );
      const b = TransactionColors(
        income: Colors.white,
        expense: Colors.white,
        transfer: Colors.white,
      );
      final result = a.lerp(b, 0.5);
      expect(result.income, isNotNull);
    });
  });
}
