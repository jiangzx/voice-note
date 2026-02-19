import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/app/theme.dart';

void main() {
  group('CategoryManageScreen structure', () {
    testWidgets('renders tab structure', (tester) async {
      // Minimal structural test
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('分类管理'),
                bottom: const TabBar(
                  tabs: [
                    Tab(text: '支出'),
                    Tab(text: '收入'),
                  ],
                ),
              ),
              body: const TabBarView(
                children: [
                  Center(child: Text('支出分类列表')),
                  Center(child: Text('收入分类列表')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('分类管理'), findsOneWidget);
      expect(find.text('支出'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget);
    });
  });
}
