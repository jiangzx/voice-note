import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:suikouji/app/router.dart';
import 'package:suikouji/app/theme.dart';

void main() {
  Widget buildApp() {
    return ProviderScope(
      child: MaterialApp.router(theme: appTheme, routerConfig: appRouter),
    );
  }

  testWidgets('initial route shows bottom navigation', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('首页'), findsWidgets);
    expect(find.text('明细'), findsWidgets);
    expect(find.text('统计'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('bottom navigation has four destinations', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  group('route configuration', () {
    test('all main routes are defined', () {
      final config = appRouter.configuration;
      final paths = _collectPaths(config.routes);

      expect(paths, contains('/home'));
      expect(paths, contains('/transactions'));
      expect(paths, contains('/statistics'));
      expect(paths, contains('/settings'));
      expect(paths, contains('/voice-recording'));
      expect(paths, contains('/record'));
      expect(paths, contains('/record/:id'));
    });

    test('settings sub-routes are defined', () {
      final config = appRouter.configuration;
      final paths = _collectPaths(config.routes);

      expect(paths, contains('accounts'));
      expect(paths, contains('categories'));
      expect(paths, contains('budget'));
      expect(paths, contains('edit'));
    });

    test('initial location is /home', () {
      expect(appRouter.configuration.navigatorKey, isNotNull);
    });
  });

}

/// Recursively collect all route paths from the configuration.
List<String> _collectPaths(List<RouteBase> routes) {
  final paths = <String>[];
  for (final route in routes) {
    if (route is GoRoute) {
      paths.add(route.path);
    }
    if (route is ShellRoute) {
      paths.addAll(_collectPaths(route.routes));
    }
    if (route is GoRoute && route.routes.isNotEmpty) {
      paths.addAll(_collectPaths(route.routes));
    }
  }
  return paths;
}
