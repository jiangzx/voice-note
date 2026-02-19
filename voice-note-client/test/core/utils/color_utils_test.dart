import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/utils/color_utils.dart';

void main() {
  group('colorFromArgbHex', () {
    test('parses opaque green', () {
      final color = colorFromArgbHex('FF4CAF50');
      expect(color, const Color(0xFF4CAF50));
    });

    test('parses semi-transparent red', () {
      final color = colorFromArgbHex('80FF0000');
      expect(color, const Color(0x80FF0000));
    });
  });

  group('colorToArgbHex', () {
    test('converts opaque green', () {
      final hex = colorToArgbHex(const Color(0xFF4CAF50));
      expect(hex, 'FF4CAF50');
    });

    test('round-trip preserves value', () {
      const original = 'FFEF5350';
      final color = colorFromArgbHex(original);
      expect(colorToArgbHex(color), original);
    });
  });
}
