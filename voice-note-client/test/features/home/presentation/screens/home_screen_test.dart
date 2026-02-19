import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';
import 'package:suikouji/features/home/presentation/widgets/summary_card.dart';

void main() {
  group('SummaryCard', () {
    testWidgets('displays income and expense', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const Scaffold(
            body: SummaryCard(totalIncome: 1500, totalExpense: 800),
          ),
        ),
      );

      expect(find.text('本月收支'), findsOneWidget);
      expect(find.text('¥1500.00'), findsOneWidget);
      expect(find.text('¥800.00'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
    });

    testWidgets('displays zero values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const Scaffold(
            body: SummaryCard(totalIncome: 0, totalExpense: 0),
          ),
        ),
      );

      expect(find.text('¥0.00'), findsNWidgets(2));
    });
  });
}
