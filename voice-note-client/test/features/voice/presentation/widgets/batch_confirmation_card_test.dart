import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';
import 'package:suikouji/features/voice/domain/draft_batch.dart';
import 'package:suikouji/features/voice/domain/parse_result.dart';
import 'package:suikouji/features/voice/presentation/widgets/batch_confirmation_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildTheme(Colors.teal, Brightness.light),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

DraftBatch _sampleBatch({int count = 3}) {
  return DraftBatch.fromResults([
    for (var i = 0; i < count; i++)
      ParseResult(
        amount: (i + 1) * 10.0,
        category: ['餐饮', '交通', '购物', '娱乐', '医疗'][i % 5],
        type: i == 0 ? 'INCOME' : 'EXPENSE',
        description: '第${i + 1}笔',
        confidence: 0.9,
        source: i.isEven ? ParseSource.llm : ParseSource.local,
      ),
  ]);
}

void main() {
  group('BatchConfirmationCard', () {
    testWidgets('renders all items', (tester) async {
      final batch = _sampleBatch(count: 3);
      await tester.pumpWidget(_wrap(BatchConfirmationCard(batch: batch)));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('¥10.00'), findsOneWidget);
      expect(find.text('¥20.00'), findsOneWidget);
      expect(find.text('¥30.00'), findsOneWidget);
    });

    testWidgets('shows pending count badge', (tester) async {
      final batch = _sampleBatch(count: 2);
      await tester.pumpWidget(_wrap(BatchConfirmationCard(batch: batch)));
      await tester.pumpAndSettle();

      expect(find.text('2 笔待确认'), findsOneWidget);
      expect(find.text('共 2 笔'), findsOneWidget);
    });

    testWidgets('shows confirmed status icon', (tester) async {
      var batch = _sampleBatch(count: 2);
      batch = batch.confirmItem(0);

      await tester.pumpWidget(_wrap(BatchConfirmationCard(batch: batch)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('1 笔待确认'), findsOneWidget);
    });

    testWidgets('shows cancelled status icon', (tester) async {
      var batch = _sampleBatch(count: 2);
      batch = batch.cancelItem(0);

      await tester.pumpWidget(_wrap(BatchConfirmationCard(batch: batch)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });

    testWidgets('confirm all button calls callback', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          BatchConfirmationCard(
            batch: _sampleBatch(count: 2),
            onConfirmAll: () => called = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('全部确认'));
      expect(called, isTrue);
    });

    testWidgets('cancel all button calls callback', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          BatchConfirmationCard(
            batch: _sampleBatch(count: 2),
            onCancelAll: () => called = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      expect(called, isTrue);
    });

    testWidgets('buttons disabled when no pending items', (tester) async {
      var batch = _sampleBatch(count: 1);
      batch = batch.confirmItem(0);

      var confirmCalled = false;
      var cancelCalled = false;

      await tester.pumpWidget(
        _wrap(
          BatchConfirmationCard(
            batch: batch,
            onConfirmAll: () => confirmCalled = true,
            onCancelAll: () => cancelCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('全部确认'));
      await tester.tap(find.text('取消'));
      expect(confirmCalled, isFalse);
      expect(cancelCalled, isFalse);
    });

    testWidgets('summary bar shows correct total', (tester) async {
      final batch = _sampleBatch(count: 3);
      await tester.pumpWidget(_wrap(BatchConfirmationCard(batch: batch)));
      await tester.pumpAndSettle();

      expect(find.text('¥60'), findsOneWidget);
    });

    testWidgets('single-item batch is still rendered', (tester) async {
      final batch = _sampleBatch(count: 1);
      await tester.pumpWidget(_wrap(BatchConfirmationCard(batch: batch)));
      await tester.pumpAndSettle();

      expect(find.text('1 笔待确认'), findsOneWidget);
      expect(find.text('¥10.00'), findsOneWidget);
    });

    testWidgets('4+ items enables scroll', (tester) async {
      final batch = _sampleBatch(count: 5);
      await tester.pumpWidget(_wrap(BatchConfirmationCard(batch: batch)));
      await tester.pumpAndSettle();

      expect(find.text('5 笔待确认'), findsOneWidget);
      expect(find.text('共 5 笔'), findsOneWidget);
    });

    testWidgets('type chips show correct labels', (tester) async {
      final batch = _sampleBatch(count: 2);
      await tester.pumpWidget(_wrap(BatchConfirmationCard(batch: batch)));
      await tester.pumpAndSettle();

      expect(find.text('收入'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
    });

    testWidgets('isLoading disables confirm/cancel buttons and swipe', (
      tester,
    ) async {
      var confirmed = false;
      var cancelled = false;
      final batch = _sampleBatch(count: 2);
      await tester.pumpWidget(
        _wrap(
          BatchConfirmationCard(
            batch: batch,
            isLoading: true,
            onConfirmAll: () => confirmed = true,
            onCancelAll: () => cancelled = true,
          ),
        ),
      );
      // Use pump() instead of pumpAndSettle() — shimmer animation never settles.
      await tester.pump(const Duration(milliseconds: 500));

      final confirmButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '全部确认'),
      );
      expect(confirmButton.onPressed, isNull);

      final cancelButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '取消'),
      );
      expect(cancelButton.onPressed, isNull);

      expect(confirmed, false);
      expect(cancelled, false);
    });
  });
}
