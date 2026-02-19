import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suikouji/shared/widgets/app_shell.dart';

void main() {
  Widget buildShell({String location = '/home'}) {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const Center(child: Text('Home')),
            ),
            GoRoute(
              path: '/transactions',
              builder: (_, _) => const Center(child: Text('Transactions')),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, _) => const Center(child: Text('Settings')),
            ),
          ],
        ),
        GoRoute(
          path: '/voice-recording',
          builder: (_, _) => const Center(child: Text('Voice Recording')),
        ),
      ],
    );

    return MaterialApp.router(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      routerConfig: router,
    );
  }

  group('AppShell', () {
    testWidgets('shows voice mic FAB on home tab', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    });

    testWidgets('shows manual entry FAB (add icon) on home tab', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows bottom navigation with 3 destinations', (tester) async {
      await tester.pumpWidget(buildShell());
      await tester.pumpAndSettle();

      expect(find.text('首页'), findsOneWidget);
      expect(find.text('明细'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('hides FABs on settings tab', (tester) async {
      await tester.pumpWidget(buildShell(location: '/settings'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic_rounded), findsNothing);
      expect(find.byIcon(Icons.add), findsNothing);
    });
  });
}
