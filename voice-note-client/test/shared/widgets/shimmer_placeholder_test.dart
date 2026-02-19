import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/shared/widgets/shimmer_placeholder.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  testWidgets('card renders with shimmer effect', (tester) async {
    await tester.pumpWidget(buildApp(ShimmerPlaceholder.card()));
    await tester.pump();
    expect(find.byType(ShimmerPlaceholder), findsOneWidget);
  });

  testWidgets('listItem renders', (tester) async {
    await tester.pumpWidget(buildApp(ShimmerPlaceholder.listItem()));
    await tester.pump();
    expect(find.byType(ShimmerPlaceholder), findsOneWidget);
  });

  testWidgets('listPlaceholder renders correct item count', (tester) async {
    await tester.pumpWidget(
      buildApp(ShimmerPlaceholder.listPlaceholder(itemCount: 3)),
    );
    await tester.pump();
    expect(find.byType(ShimmerPlaceholder), findsNWidgets(3));
  });

  testWidgets('homeScreenPlaceholder renders card and list items', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildApp(ShimmerPlaceholder.homeScreenPlaceholder()),
    );
    await tester.pump();
    // 1 card + 3 list items = 4 ShimmerPlaceholder widgets
    expect(find.byType(ShimmerPlaceholder), findsNWidgets(4));
  });
}
