import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../features/transaction/presentation/screens/transaction_form_screen.dart';

/// Shell widget providing bottom navigation and FAB with container transform.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/home', '/transactions', '/statistics', '/settings'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final showFab = index < 3;
    final theme = Theme.of(context);

    return Scaffold(
      body: child,
      floatingActionButton: showFab
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Voice recording FAB
                FloatingActionButton.small(
                  heroTag: 'voice_fab',
                  onPressed: () => context.push('/voice-recording'),
                  backgroundColor: theme.colorScheme.tertiaryContainer,
                  child: Icon(
                    Icons.mic_rounded,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Manual entry FAB
                OpenContainer<void>(
                  transitionDuration: AppDuration.pageTransition,
                  openBuilder: (context, _) => const TransactionFormScreen(),
                  closedElevation: 6,
                  closedShape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.xlAll,
                  ),
                  closedColor: theme.colorScheme.primaryContainer,
                  closedBuilder: (context, openContainer) {
                    return SizedBox(
                      height: 56,
                      width: 56,
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    );
                  },
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '明细',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
