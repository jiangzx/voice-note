import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';
import 'package:suikouji/features/voice/presentation/widgets/confirmation_card.dart';

void main() {
  Widget buildWidget(
    ParseResult result, {
    FieldTapCallback? onFieldTap,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  }) {
    return MaterialApp(
      theme: buildTheme(Colors.teal, Brightness.light),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConfirmationCard(
            result: result,
            onFieldTap: onFieldTap,
            onConfirm: onConfirm,
            onCancel: onCancel,
          ),
        ),
      ),
    );
  }

  group('ConfirmationCard', () {
    testWidgets('displays expense amount and type', (tester) async {
      await tester.pumpWidget(buildWidget(
        const ParseResult(
          amount: 35.0,
          category: '餐饮',
          type: 'EXPENSE',
          source: ParseSource.local,
        ),
      ));

      expect(find.text('¥35.00'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
    });

    testWidgets('displays income type', (tester) async {
      await tester.pumpWidget(buildWidget(
        const ParseResult(
          amount: 8000.0,
          category: '工资',
          type: 'INCOME',
          source: ParseSource.local,
        ),
      ));

      expect(find.text('¥8000.00'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
    });

    testWidgets('displays all field labels', (tester) async {
      await tester.pumpWidget(buildWidget(
        const ParseResult(
          amount: 28.5,
          category: '交通',
          description: '打车',
          date: '2026-02-17',
          source: ParseSource.local,
        ),
      ));

      expect(find.text('分类'), findsOneWidget);
      expect(find.text('日期'), findsOneWidget);
      expect(find.text('备注'), findsOneWidget);
      expect(find.text('账户'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
      expect(find.text('打车'), findsOneWidget);
      expect(find.text('默认账户'), findsOneWidget);
    });

    testWidgets('shows "今天" for today\'s date', (tester) async {
      final today = DateTime.now().toIso8601String().split('T')[0];
      await tester.pumpWidget(buildWidget(
        ParseResult(
          amount: 10.0,
          category: '其他',
          date: today,
          source: ParseSource.local,
        ),
      ));

      expect(find.text('今天'), findsOneWidget);
    });

    testWidgets('shows "未识别" when category is null', (tester) async {
      await tester.pumpWidget(buildWidget(
        const ParseResult(
          amount: 50.0,
          source: ParseSource.local,
        ),
      ));

      expect(find.text('未识别'), findsOneWidget);
    });

    testWidgets('hides description row when empty', (tester) async {
      await tester.pumpWidget(buildWidget(
        const ParseResult(
          amount: 50.0,
          category: '其他',
          source: ParseSource.local,
        ),
      ));

      expect(find.text('备注'), findsNothing);
    });

    testWidgets('confirm button triggers callback', (tester) async {
      bool confirmed = false;
      await tester.pumpWidget(buildWidget(
        const ParseResult(
          amount: 35.0,
          category: '餐饮',
          source: ParseSource.local,
        ),
        onConfirm: () => confirmed = true,
      ));

      await tester.tap(find.text('确认记账'));
      expect(confirmed, isTrue);
    });

    testWidgets('cancel button triggers callback', (tester) async {
      bool cancelled = false;
      await tester.pumpWidget(buildWidget(
        const ParseResult(
          amount: 35.0,
          category: '餐饮',
          source: ParseSource.local,
        ),
        onCancel: () => cancelled = true,
      ));

      await tester.tap(find.text('取消'));
      expect(cancelled, isTrue);
    });

    testWidgets('field tap triggers callback with field name', (tester) async {
      String? tappedField;
      await tester.pumpWidget(buildWidget(
        const ParseResult(
          amount: 35.0,
          category: '餐饮',
          source: ParseSource.local,
        ),
        onFieldTap: (field, value) => tappedField = field,
      ));

      await tester.tap(find.text('餐饮'));
      expect(tappedField, 'category');
    });
  });
}
