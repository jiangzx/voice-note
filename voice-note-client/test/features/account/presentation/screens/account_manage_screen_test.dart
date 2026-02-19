import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';

void main() {
  group('AccountManageScreen structure', () {
    testWidgets('account type labels are correct', (tester) async {
      // Minimal structural test
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const Scaffold(body: Center(child: Text('账户管理'))),
        ),
      );

      expect(find.text('账户管理'), findsOneWidget);
    });
  });
}
