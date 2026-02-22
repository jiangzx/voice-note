import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/features/transaction/presentation/widgets/filter_bar.dart';

void main() {
  Widget buildApp(FilterBar widget) {
    return MaterialApp(home: Scaffold(body: widget));
  }

  testWidgets('renders search field and chips', (tester) async {
    await tester.pumpWidget(
      buildApp(
        FilterBar(
          selectedDatePreset: DateRangePreset.thisMonth,
          selectedType: null,
          searchQuery: '',
          onDatePresetChanged: (_) {},
          onTypeChanged: (_) {},
          onSearchChanged: (_) {},
          onAdvancedFilter: () {},
        ),
      ),
    );

    expect(find.text('搜索描述...'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('本月'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('转账'), findsNothing);
  });

  testWidgets('search controller syncs with external searchQuery', (
    tester,
  ) async {
    String searchQuery = '';
    late StateSetter setOuterState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setOuterState = setState;
              return FilterBar(
                selectedDatePreset: DateRangePreset.thisMonth,
                selectedType: null,
                searchQuery: searchQuery,
                onDatePresetChanged: (_) {},
                onTypeChanged: (_) {},
                onSearchChanged: (_) {},
                onAdvancedFilter: () {},
              );
            },
          ),
        ),
      ),
    );

    setOuterState(() => searchQuery = '午饭');
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, '午饭');
  });

  testWidgets('controller disposes cleanly', (tester) async {
    await tester.pumpWidget(
      buildApp(
        FilterBar(
          selectedDatePreset: DateRangePreset.thisMonth,
          selectedType: null,
          searchQuery: 'test',
          onDatePresetChanged: (_) {},
          onTypeChanged: (_) {},
          onSearchChanged: (_) {},
          onAdvancedFilter: () {},
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    await tester.pump();
  });
}
