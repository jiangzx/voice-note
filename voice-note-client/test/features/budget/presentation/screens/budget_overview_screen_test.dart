import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';
import 'package:suikouji/features/budget/domain/models/budget_status.dart';
import 'package:suikouji/features/budget/presentation/widgets/budget_progress_bar.dart';

void main() {
  group('BudgetStatus', () {
    test('percentage calculation', () {
      const status = BudgetStatus(
        categoryId: 'c1',
        categoryName: '餐饮',
        budgetAmount: 1000,
        spentAmount: 800,
      );
      expect(status.percentage, 80.0);
      expect(status.level, BudgetLevel.warning);
      expect(status.remaining, 200.0);
    });

    test('exceeded level when over 100%', () {
      const status = BudgetStatus(
        categoryId: 'c2',
        categoryName: '购物',
        budgetAmount: 500,
        spentAmount: 600,
      );
      expect(status.percentage, 120.0);
      expect(status.level, BudgetLevel.exceeded);
      expect(status.remaining, -100.0);
    });

    test('normal level when below 80%', () {
      const status = BudgetStatus(
        categoryId: 'c3',
        categoryName: '交通',
        budgetAmount: 1000,
        spentAmount: 500,
      );
      expect(status.percentage, 50.0);
      expect(status.level, BudgetLevel.normal);
    });

    test('zero budget returns 0% with no error', () {
      const status = BudgetStatus(
        categoryId: 'c4',
        categoryName: '其他',
        budgetAmount: 0,
        spentAmount: 100,
      );
      expect(status.percentage, 0.0);
      expect(status.level, BudgetLevel.normal);
    });
  });

  group('BudgetProgressBar', () {
    testWidgets('renders amount text', (tester) async {
      const status = BudgetStatus(
        categoryId: 'c1',
        categoryName: '餐饮',
        budgetAmount: 2000,
        spentAmount: 1500,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              child: BudgetProgressBar(status: status),
            ),
          ),
        ),
      );

      expect(find.text('¥1500 / ¥2000'), findsOneWidget);
    });

    testWidgets('renders with zero amount', (tester) async {
      const status = BudgetStatus(
        categoryId: 'c2',
        categoryName: '购物',
        budgetAmount: 1000,
        spentAmount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              child: BudgetProgressBar(status: status),
            ),
          ),
        ),
      );

      expect(find.text('¥0 / ¥1000'), findsOneWidget);
    });
  });
}
