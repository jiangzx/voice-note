import 'package:flutter/material.dart';

import 'design_tokens.dart';

// --- Semantic palette (light only, per spec) ---
abstract final class AppColors {
  static const Color backgroundPrimary = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF8F9FA);
  static const Color backgroundTertiary = Color(0xFFF5F7FA);
  static const Color textPrimary = Color(0xFF1D2129);
  static const Color textSecondary = Color(0xFF4E5969);
  static const Color textPlaceholder = Color(0xFF86909C);
  static const Color brandPrimary = Color(0xFF1677FF);
  static const Color income = Color(0xFF00B42A);
  static const Color expense = Color(0xFFF53F3F);
  static const Color divider = Color(0xFFF2F3F5);
}

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
  income: AppColors.income,
  expense: AppColors.expense,
  transfer: AppColors.brandPrimary,
);

const _darkTransactionColors = TransactionColors(
  income: Color(0xFF66BB6A),
  expense: Color(0xFFEF5350),
  transfer: Color(0xFF42A5F5),
);

/// Predefined theme color seeds (for settings picker; app uses fixed light palette).
abstract final class AppThemeColors {
  static const Color teal = Colors.teal;
  static const Color indigo = Colors.indigo;
  static const Color orange = Colors.orange;
  static const Color purple = Colors.purple;
  static const Color pink = Colors.pink;
  static const Color green = Colors.green;
  static const Color brand = AppColors.brandPrimary;

  static const List<Color> presets = [
    brand,
    teal,
    indigo,
    orange,
    purple,
    pink,
    green,
  ];

  static const List<String> presetNames = [
    '亮蓝',
    '青色',
    '靛蓝',
    '橙色',
    '紫色',
    '粉色',
    '绿色',
  ];
}

/// Light ColorScheme from semantic palette.
ColorScheme _lightColorScheme() {
  return ColorScheme.light(
    primary: AppColors.brandPrimary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.brandPrimary.withValues(alpha: 0.12),
    onPrimaryContainer: AppColors.brandPrimary,
    secondary: AppColors.backgroundTertiary,
    onSecondary: AppColors.textPrimary,
    secondaryContainer: AppColors.backgroundTertiary,
    onSecondaryContainer: AppColors.textSecondary,
    tertiary: AppColors.income,
    onTertiary: Colors.white,
    error: AppColors.expense,
    onError: Colors.white,
    errorContainer: AppColors.expense.withValues(alpha: 0.12),
    onErrorContainer: AppColors.expense,
    surface: AppColors.backgroundPrimary,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.backgroundSecondary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.divider,
    outlineVariant: AppColors.divider,
    shadow: Colors.black26,
    scrim: Colors.black54,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.backgroundPrimary,
    surfaceTint: AppColors.brandPrimary,
  );
}

/// Build light ThemeData for 亮白极简 design system.
ThemeData buildLightTheme() {
  final colorScheme = _lightColorScheme();
  final textTheme = _buildTextTheme(colorScheme);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.backgroundPrimary,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.backgroundPrimary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: AppIconSize.md),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.backgroundPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.backgroundPrimary,
      border: const OutlineInputBorder(borderRadius: AppRadius.inputAll),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.inputAll,
        borderSide: BorderSide(color: AppColors.divider),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.inputAll,
        borderSide: BorderSide(color: AppColors.brandPrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textPlaceholder),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      tileColor: Colors.transparent,
      titleTextStyle: textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      iconColor: AppColors.textSecondary,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.brandPrimary,
      foregroundColor: Colors.white,
      elevation: 2,
      focusElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.backgroundPrimary,
      elevation: 0,
      height: 80,
      indicatorColor: AppColors.brandPrimary.withValues(alpha: 0.12),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.brandPrimary, size: AppIconSize.md);
        }
        return const IconThemeData(color: AppColors.textPlaceholder, size: AppIconSize.md);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return textTheme.labelMedium?.copyWith(color: AppColors.brandPrimary);
        }
        return textTheme.labelMedium?.copyWith(color: AppColors.textPlaceholder);
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.brandPrimary;
          return AppColors.backgroundTertiary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textPrimary;
        }),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        )),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
        )),
      ),
    ),
    // OFF-state track/thumb with sufficient contrast on light background.
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return null;
        return const Color(0xFFD0D3D9);
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return null;
        return Colors.white;
      }),
    ),
    extensions: const <ThemeExtension<dynamic>>[_lightTransactionColors],
  );
}

TextTheme _buildTextTheme(ColorScheme colorScheme) {
  return const TextTheme(
    displayLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    displayMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    displaySmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    headlineLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    headlineSmall: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: AppColors.textPrimary),
    titleSmall: TextStyle(color: AppColors.textPrimary),
    bodyLarge: TextStyle(color: AppColors.textPrimary),
    bodyMedium: TextStyle(color: AppColors.textSecondary),
    bodySmall: TextStyle(color: AppColors.textSecondary),
    labelLarge: TextStyle(color: AppColors.textPrimary),
    labelMedium: TextStyle(color: AppColors.textSecondary),
    labelSmall: TextStyle(color: AppColors.textPlaceholder),
  );
}

/// Build a ThemeData with the given seed color and brightness (kept for theme picker / dark fallback).
ThemeData buildTheme(Color seedColor, Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  if (!isDark) return buildLightTheme();
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: seedColor,
    brightness: brightness,
    extensions: const <ThemeExtension<dynamic>>[_darkTransactionColors],
  );
}

/// Default light theme (used by app).
final ThemeData appTheme = buildLightTheme();

/// Default dark theme (fallback only; not part of 亮白极简 spec).
final ThemeData appDarkTheme = buildTheme(AppThemeColors.brand, Brightness.dark);
