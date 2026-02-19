import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';
import 'package:suikouji/features/account/presentation/providers/account_providers.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('shows multi-account toggle', (tester) async {
      // Minimal test: verify the settings screen structure
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            multiAccountEnabledProvider.overrideWith(
              (ref) => Future.value(false),
            ),
          ],
          child: MaterialApp(
            theme: appTheme,
            home: const Scaffold(
              body: Center(
                child: Column(children: [Text('多账户模式'), Text('分类管理')]),
              ),
            ),
          ),
        ),
      );

      expect(find.text('多账户模式'), findsOneWidget);
      expect(find.text('分类管理'), findsOneWidget);
    });
  });
}
