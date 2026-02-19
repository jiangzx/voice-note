import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/shared/widgets/error_state_widget.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders error icon and message', (tester) async {
    await tester.pumpWidget(buildApp(const ErrorStateWidget(message: '加载失败')));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('加载失败'), findsOneWidget);
  });

  testWidgets('renders retry button and fires callback', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      buildApp(
        ErrorStateWidget(message: '加载失败', onRetry: () => retried = true),
      ),
    );

    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });

  testWidgets('hides retry button when onRetry is null', (tester) async {
    await tester.pumpWidget(buildApp(const ErrorStateWidget(message: '加载失败')));

    expect(find.text('重试'), findsNothing);
  });
}
