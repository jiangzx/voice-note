import 'package:flutter/material.dart';

/// Spacing tokens based on 4px grid system.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Border radius tokens. Cards/buttons 16-24px, input 28-32px per spec.
abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  /// Card and primary button radius (16-24px).
  static const double card = 20;
  /// Core input bar radius (28-32px).
  static const double input = 28;
  static const double full = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius inputAll = BorderRadius.all(Radius.circular(input));
}

/// Icon size tokens.
abstract final class AppIconSize {
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 48;
  static const double xl = 64;
}

/// Animation duration tokens.
abstract final class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration pageTransition = Duration(milliseconds: 400);
}

/// Light soft shadow for elevation (Y ≤2, blur ≤8, alpha ≤0.15).
abstract final class AppShadow {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x26000000),
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];
  static const List<BoxShadow> input = [
    BoxShadow(
      color: Color(0x26000000),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];
}
