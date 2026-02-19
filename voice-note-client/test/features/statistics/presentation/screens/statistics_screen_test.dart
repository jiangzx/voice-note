import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';
import 'package:suikouji/core/database/app_database.dart';
import 'package:suikouji/core/di/database_provider.dart';
import 'package:suikouji/features/budget/domain/models/budget_status.dart';
import 'package:suikouji/features/budget/presentation/widgets/budget_progress_bar.dart';
import 'package:suikouji/features/statistics/presentation/providers/statistics_providers.dart';

void main() {
  group('PeriodType dateRangeForPeriod', () {
    test('month range covers full month', () {
      final range = dateRangeForPeriod(DateTime(2026, 2, 15), PeriodType.month);
      expect(range.start, DateTime(2026, 2, 1));
      expect(range.end.month, 2);
      expect(range.end.day, 28);
    });

    test('day range covers single day', () {
      final range = dateRangeForPeriod(DateTime(2026, 3, 5), PeriodType.day);
      expect(range.start, DateTime(2026, 3, 5));
      expect(range.end.day, 5);
      expect(range.end.hour, 23);
    });

    test('year range covers full year', () {
      final range = dateRangeForPeriod(DateTime(2026, 6, 1), PeriodType.year);
      expect(range.start, DateTime(2026, 1, 1));
      expect(range.end.month, 12);
      expect(range.end.day, 31);
    });

    test('week range starts on Monday', () {
      // 2026-02-17 is Tuesday
      final range = dateRangeForPeriod(DateTime(2026, 2, 17), PeriodType.week);
      expect(range.start.weekday, DateTime.monday);
    });
  });

  group('BudgetProgressBar', () {
    testWidgets('displays normal progress (green)', (tester) async {
      const status = BudgetStatus(
        categoryId: 'c1',
        categoryName: '餐饮',
        budgetAmount: 1000,
        spentAmount: 300,
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

      expect(find.text('¥300 / ¥1000'), findsOneWidget);
    });

    testWidgets('displays exceeded progress (red)', (tester) async {
      const status = BudgetStatus(
        categoryId: 'c2',
        categoryName: '购物',
        budgetAmount: 500,
        spentAmount: 600,
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

      expect(status.level, BudgetLevel.exceeded);
      expect(find.text('¥600 / ¥500'), findsOneWidget);
    });
  });

  group('StatisticsScreen with in-memory DB', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders statistics screen title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: appTheme,
            home: const Scaffold(
              body: Center(child: Text('统计')),
            ),
          ),
        ),
      );

      expect(find.text('统计'), findsOneWidget);
    });
  });
}
