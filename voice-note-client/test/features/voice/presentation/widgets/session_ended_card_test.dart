import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/voice/presentation/widgets/session_ended_card.dart';

void main() {
  Widget buildWidget({
    int transactionCount = 0,
    VoidCallback? onRestart,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: Scaffold(
        body: SessionEndedCard(
          transactionCount: transactionCount,
          onRestart: onRestart ?? () {},
        ),
      ),
    );
  }

  group('SessionEndedCard', () {
    testWidgets('shows generic text when no transactions', (tester) async {
      await tester.pumpWidget(buildWidget(transactionCount: 0));

      expect(find.text('会话已结束'), findsOneWidget);
      expect(find.text('开始新一轮'), findsOneWidget);
    });

    testWidgets('shows transaction count when > 0', (tester) async {
      await tester.pumpWidget(buildWidget(transactionCount: 3));

      expect(find.text('本次记录了 3 笔交易'), findsOneWidget);
    });

    testWidgets('restart button triggers callback', (tester) async {
      var restartCalled = false;
      await tester.pumpWidget(
        buildWidget(onRestart: () => restartCalled = true),
      );

      await tester.tap(find.text('开始新一轮'));
      expect(restartCalled, isTrue);
    });

    testWidgets('shows check icon', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(
        find.byIcon(Icons.check_circle_outline_rounded),
        findsOneWidget,
      );
    });

    testWidgets('shows refresh icon on restart button', (tester) async {
      await tester.pumpWidget(buildWidget());

      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });
}
