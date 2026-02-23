import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/shared/error_copy.dart';
import 'package:suikouji/shared/widgets/error_state_widget.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders error icon and message', (tester) async {
    await tester.pumpWidget(
      buildApp(ErrorStateWidget(message: ErrorCopy.loadFailed)),
    );

    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.text(ErrorCopy.loadFailed), findsOneWidget);
  });

  testWidgets('renders retry button and fires callback', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      buildApp(
        ErrorStateWidget(
          message: ErrorCopy.loadFailed,
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });

  testWidgets('hides retry button when onRetry is null', (tester) async {
    await tester.pumpWidget(
      buildApp(ErrorStateWidget(message: ErrorCopy.loadFailed)),
    );

    expect(find.text('重试'), findsNothing);
  });
}
