import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/shared/widgets/empty_state_widget.dart';

void main() {
  Widget buildApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders icon and title', (tester) async {
    await tester.pumpWidget(
      buildApp(const EmptyStateWidget(icon: Icons.inbox, title: '暂无数据')),
    );

    expect(find.byIcon(Icons.inbox), findsOneWidget);
    expect(find.text('暂无数据'), findsOneWidget);
  });

  testWidgets('renders description when provided', (tester) async {
    await tester.pumpWidget(
      buildApp(
        const EmptyStateWidget(
          icon: Icons.inbox,
          title: '暂无数据',
          description: '点击添加',
        ),
      ),
    );

    expect(find.text('点击添加'), findsOneWidget);
  });

  testWidgets('hides description when null', (tester) async {
    await tester.pumpWidget(
      buildApp(const EmptyStateWidget(icon: Icons.inbox, title: '暂无数据')),
    );

    expect(find.text('点击添加'), findsNothing);
  });

  testWidgets('renders action button and fires callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      buildApp(
        EmptyStateWidget(
          icon: Icons.inbox,
          title: '暂无数据',
          actionLabel: '添加',
          onAction: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text('添加'));
    expect(tapped, isTrue);
  });
}
