import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/utils/icon_utils.dart';

void main() {
  group('iconFromString', () {
    testWidgets('parses material icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: iconFromString('material:restaurant')),
      );
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
    });

    testWidgets('falls back to category icon for unknown material name', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: iconFromString('material:nonexistent_icon')),
      );
      expect(find.byIcon(Icons.category), findsOneWidget);
    });

    testWidgets('parses emoji icon', (tester) async {
      await tester.pumpWidget(MaterialApp(home: iconFromString('emoji:🍜')));
      expect(find.text('🍜'), findsOneWidget);
    });

    testWidgets('returns help icon for unknown format', (tester) async {
      await tester.pumpWidget(MaterialApp(home: iconFromString('unknown:foo')));
      expect(find.byIcon(Icons.help_outline), findsOneWidget);
    });
  });
}
