import 'dart:ui';

/// Converts an 8-character ARGB hex string (without #) to a [Color].
/// Example: 'FF4CAF50' → Color(0xFF4CAF50)
Color colorFromArgbHex(String hex) {
  return Color(int.parse(hex, radix: 16));
}

/// Converts a [Color] to an 8-character ARGB hex string (without #).
/// Example: Color(0xFF4CAF50) → 'FF4CAF50'
String colorToArgbHex(Color color) {
  // ignore: deprecated_member_use
  return color.value.toRadixString(16).padLeft(8, '0').toUpperCase();
}
