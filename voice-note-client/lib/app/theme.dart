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
  /// Unselected gesture lock node stroke (industry spec).
  static const Color gestureNodeStroke = Color(0xFFE5E6EB);
  /// Soft error surface for friendly hints (not destructive); enterprise-style.
  static const Color softErrorBackground = Color(0xFFFDF6EF);
  static const Color softErrorText = Color(0xFF8B6914);
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

/// 交易金额用色：收入金黄、支出黑（与 AppColors 分离，避免影响删除/错误等红色语义）
const _lightTransactionColors = TransactionColors(
  income: Color(0xFFD4A017),
  expense: Color(0xFF000000),
  transfer: AppColors.brandPrimary,
);

const _darkTransactionColors = TransactionColors(
  income: Color(0xFFE6B800),
  expense: Color(0xFFE5E6EB),
  transfer: Color(0xFF42A5F5),
);

/// Returns [TransactionColors] from [theme], or scheme-based fallback when extension is not registered (e.g. tests).
TransactionColors transactionColorsOrFallback(ThemeData theme) {
  final ext = theme.extension<TransactionColors>();
  if (ext != null) return ext;
  final s = theme.colorScheme;
  return TransactionColors(income: s.tertiary, expense: s.error, transfer: s.primary);
}

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
    /// Unified soft error hint (ErrorStateWidget / SnackBar / chat bubble); not destructive red.
    errorContainer: AppColors.softErrorBackground,
    onErrorContainer: AppColors.softErrorText,
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
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        color: AppColors.textPrimary,
        textBaseline: TextBaseline.alphabetic,
      ),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
        textBaseline: TextBaseline.alphabetic,
      ),
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
      height: 56,
      indicatorColor: AppColors.brandPrimary.withValues(alpha: 0.12),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Color(0xFF1677FF), size: 24);
        }
        return const IconThemeData(color: Color(0xFF666666), size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return textTheme.labelMedium?.copyWith(
            color: const Color(0xFF1677FF),
            fontSize: 24,
            fontWeight: FontWeight.w500,
          );
        }
        return textTheme.labelMedium?.copyWith(
          color: const Color(0xFF666666),
          fontSize: 22,
          fontWeight: FontWeight.w400,
        );
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

/// Base for all theme TextStyles so ThemeData.lerp and ListTile defaults get non-null inherit/textBaseline.
const TextStyle _textThemeBase = TextStyle(
  inherit: false,
  textBaseline: TextBaseline.alphabetic,
);

TextTheme _buildTextTheme(ColorScheme colorScheme) {
  return TextTheme(
    displayLarge: _textThemeBase.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    displayMedium: _textThemeBase.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    displaySmall: _textThemeBase.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    headlineLarge: _textThemeBase.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    headlineMedium: _textThemeBase.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    headlineSmall: _textThemeBase.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    titleLarge: _textThemeBase.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
    titleMedium: _textThemeBase.copyWith(color: AppColors.textPrimary),
    titleSmall: _textThemeBase.copyWith(color: AppColors.textPrimary),
    bodyLarge: _textThemeBase.copyWith(color: AppColors.textPrimary),
    bodyMedium: _textThemeBase.copyWith(color: AppColors.textSecondary),
    bodySmall: _textThemeBase.copyWith(color: AppColors.textSecondary),
    labelLarge: _textThemeBase.copyWith(color: AppColors.textPrimary),
    labelMedium: _textThemeBase.copyWith(color: AppColors.textSecondary),
    labelSmall: _textThemeBase.copyWith(color: AppColors.textPlaceholder),
  );
}

/// TextTheme with inherit: false and textBaseline for a ColorScheme (enables ThemeData.lerp when switching theme).
TextTheme _buildTextThemeFromScheme(ColorScheme scheme) {
  final Color onSurface = scheme.onSurface;
  final Color onVariant = scheme.onSurfaceVariant;
  return TextTheme(
    displayLarge: _textThemeBase.copyWith(color: onSurface, fontWeight: FontWeight.w600),
    displayMedium: _textThemeBase.copyWith(color: onSurface, fontWeight: FontWeight.w600),
    displaySmall: _textThemeBase.copyWith(color: onSurface, fontWeight: FontWeight.w600),
    headlineLarge: _textThemeBase.copyWith(color: onSurface, fontWeight: FontWeight.w600),
    headlineMedium: _textThemeBase.copyWith(color: onSurface, fontWeight: FontWeight.w600),
    headlineSmall: _textThemeBase.copyWith(color: onSurface, fontWeight: FontWeight.w600),
    titleLarge: _textThemeBase.copyWith(color: onSurface, fontWeight: FontWeight.w600),
    titleMedium: _textThemeBase.copyWith(color: onSurface),
    titleSmall: _textThemeBase.copyWith(color: onSurface),
    bodyLarge: _textThemeBase.copyWith(color: onSurface),
    bodyMedium: _textThemeBase.copyWith(color: onVariant),
    bodySmall: _textThemeBase.copyWith(color: onVariant),
    labelLarge: _textThemeBase.copyWith(color: onSurface),
    labelMedium: _textThemeBase.copyWith(color: onVariant),
    labelSmall: _textThemeBase.copyWith(color: onVariant),
  );
}

/// Build a ThemeData with the given seed color and brightness (kept for theme picker / dark fallback).
ThemeData buildTheme(Color seedColor, Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  if (!isDark) return buildLightTheme();
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );
  final textTheme = _buildTextThemeFromScheme(colorScheme);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: AppIconSize.md),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      border: const OutlineInputBorder(borderRadius: AppRadius.inputAll),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputAll,
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.inputAll,
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      hintStyle: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      tileColor: Colors.transparent,
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
        textBaseline: TextBaseline.alphabetic,
      ),
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        textBaseline: TextBaseline.alphabetic,
      ),
      iconColor: colorScheme.onSurfaceVariant,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 2,
      focusElevation: 4,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      height: 56,
      indicatorColor: colorScheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colorScheme.primary, size: 24);
        }
        return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          );
        }
        return textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontSize: 22,
          fontWeight: FontWeight.w400,
        );
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.surfaceContainerHighest;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.onPrimary;
          return colorScheme.onSurface;
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
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return null;
        return colorScheme.surfaceContainerHighest;
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return null;
        return colorScheme.outline;
      }),
    ),
    extensions: const <ThemeExtension<dynamic>>[_darkTransactionColors],
  );
}

/// Default light theme (used by app).
final ThemeData appTheme = buildLightTheme();

/// Default dark theme (fallback only; not part of 亮白极简 spec).
final ThemeData appDarkTheme = buildTheme(AppThemeColors.brand, Brightness.dark);
