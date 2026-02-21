import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../../features/transaction/presentation/screens/transaction_form_screen.dart';
import 'animated_voice_fab.dart';
import 'fab_visibility_provider.dart';

/// Custom FAB location for transaction page to avoid overlapping with bottom action bar.
/// 
/// Positions the FAB column so that the bottom edge of the "+" FAB aligns with
/// the top border line of the bottom action bar (delete button bar).
class _TransactionPageFabLocation extends FloatingActionButtonLocation {
  const _TransactionPageFabLocation();

  // FAB尺寸和间距常量
  static const double _fabHeight = 56.0;
  static const double _fabWidth = 56.0;
  static const double _fabSpacing = 8.0; // AppSpacing.sm
  
  // 底部导航栏和操作栏高度常量
  static const double _bottomNavBarHeight = 80.0; // NavigationBar高度（约80px，包含SafeArea）
  static const double _actionBarHeight = 100.0; // 操作栏高度（padding 24px + SafeArea 20-30px + 内容48px）

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // X坐标：右侧对齐，考虑SafeArea和边距
    final double endX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.minInsets.right -
        kFloatingActionButtonMargin -
        _fabWidth;

    // Y坐标计算：
    // contentBottom是AppShell底部导航栏的顶部位置
    // 操作栏显示在TransactionListScreen的Scaffold中，位于底部导航栏上方
    // 需要减去底部导航栏高度和操作栏高度，得到操作栏顶部位置（border线位置）
    final double borderLineY = scaffoldGeometry.contentBottom - 
        _bottomNavBarHeight - 
        _actionBarHeight;

    // FAB Column结构：语音FAB + 间距 + +号FAB
    // 目标：+号FAB底部对齐到border线
    // 
    // 计算步骤：
    // 1. +号FAB底部Y = borderLineY
    // 2. +号FAB顶部Y = borderLineY - _fabHeight
    // 3. 语音FAB底部Y = +号FAB顶部Y - _fabSpacing
    // 4. Column顶部Y = 语音FAB底部Y - _fabHeight
    final double plusFabBottomY = borderLineY;
    final double plusFabTopY = plusFabBottomY - _fabHeight;
    final double voiceFabBottomY = plusFabTopY - _fabSpacing;
    final double columnTopY = voiceFabBottomY - _fabHeight;
    final double endY = columnTopY;

    return Offset(endX, endY);
  }

  @override
  String toString() => 'FloatingActionButtonLocation.transactionPage';
}

/// Shell widget providing bottom navigation and FAB with container transform.
class AppShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final showFab = index < 3;
    final location = GoRouterState.of(context).uri.path;
    final isTransactionPage = location.startsWith('/transactions');
    
    // Only enable visibility control on transaction page
    final fabVisible = isTransactionPage
        ? ref.watch(fabVisibilityProvider)
        : true;

    return Scaffold(
      body: child,
      floatingActionButton: showFab
          ? AnimatedOpacity(
              opacity: fabVisible ? 1.0 : 0.0,
              duration: AppDuration.normal,
              child: IgnorePointer(
                ignoring: !fabVisible,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Voice recording FAB with animation
                    const AnimatedVoiceFab(),
                    const SizedBox(height: AppSpacing.sm),
                    // Manual entry FAB
                    OpenContainer<void>(
                      transitionDuration: AppDuration.pageTransition,
                      openBuilder: (context, _) => const TransactionFormScreen(),
                      closedElevation: 2,
                      closedShape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.cardAll,
                      ),
                      closedColor: AppColors.brandPrimary,
                      closedBuilder: (context, openContainer) {
                        return SizedBox(
                          height: 56,
                          width: 56,
                          child: Center(
                            child: Icon(
                              Icons.add,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: isTransactionPage
          ? const _TransactionPageFabLocation()
          : FloatingActionButtonLocation.endFloat,
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
