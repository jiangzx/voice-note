import 'package:flutter/material.dart';

/// Semantic color extension for transaction types.
@immutable
class TransactionColors extends ThemeExtension<TransactionColors> {
  final Color income;
  final Color expense;
  final Color transfer;

  const TransactionColors({
    required this.income,
    required this.expense,
    required this.transfer,
  });

  @override
  TransactionColors copyWith({Color? income, Color? expense, Color? transfer}) {
    return TransactionColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
    );
  }

  @override
  TransactionColors lerp(TransactionColors? other, double t) {
    if (other is! TransactionColors) return this;
    return TransactionColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
    );
  }
}

const _lightTransactionColors = TransactionColors(
  income: Color(0xFF2E7D32),
  expense: Color(0xFFC62828),
  transfer: Color(0xFF1565C0),
);

const _darkTransactionColors = TransactionColors(
  income: Color(0xFF66BB6A),
  expense: Color(0xFFEF5350),
  transfer: Color(0xFF42A5F5),
);

/// Predefined theme color seeds.
abstract final class AppThemeColors {
  static const Color teal = Colors.teal;
  static const Color indigo = Colors.indigo;
  static const Color orange = Colors.orange;
  static const Color purple = Colors.purple;
  static const Color pink = Colors.pink;
  static const Color green = Colors.green;

  static const List<Color> presets = [
    teal,
    indigo,
    orange,
    purple,
    pink,
    green,
  ];

  static const List<String> presetNames = ['青色', '靛蓝', '橙色', '紫色', '粉色', '绿色'];
}

/// Build a ThemeData with the given seed color and brightness.
ThemeData buildTheme(Color seedColor, Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: seedColor,
    brightness: brightness,
    extensions: <ThemeExtension<dynamic>>[
      isDark ? _darkTransactionColors : _lightTransactionColors,
    ],
  );
}

/// Default light theme for backwards compatibility.
final ThemeData appTheme = buildTheme(AppThemeColors.teal, Brightness.light);

/// Default dark theme.
final ThemeData appDarkTheme = buildTheme(AppThemeColors.teal, Brightness.dark);
