import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../../features/settings/presentation/providers/home_fab_preference_provider.dart';
import '../../features/transaction/presentation/screens/transaction_form_screen.dart';
import 'animated_voice_fab.dart';
import 'draggable_fab_group.dart';

/// FAB group size: width 56, height 56+8+56=120.
const Size kFabGroupSize = Size(56, 120);

const String _keyFabGroupDx = 'fab_group_offset_dx';
const String _keyFabGroupDy = 'fab_group_offset_dy';

/// Holds FAB offset in local state so drag/snap only rebuild this subtree, not [child].
class _DraggableFabOverlay extends StatefulWidget {
  const _DraggableFabOverlay({
    required this.initialOffset,
    required this.onSnapEnd,
    required this.fabChild,
  });

  final Offset? initialOffset;
  final void Function(Offset) onSnapEnd;
  final Widget fabChild;

  @override
  State<_DraggableFabOverlay> createState() => _DraggableFabOverlayState();
}

class _DraggableFabOverlayState extends State<_DraggableFabOverlay> {
  Offset? _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
  }

  @override
  void didUpdateWidget(_DraggableFabOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialOffset != widget.initialOffset) {
      _offset = widget.initialOffset;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const minX = 0.0;
        final maxX = (w - kFabGroupSize.width).clamp(0.0, double.infinity);
        const minY = 0.0;
        final maxY = (h - kFabGroupSize.height).clamp(0.0, double.infinity);
        final defaultOffset = Offset(
          w - kFloatingActionButtonMargin - kFabGroupSize.width,
          h - kFloatingActionButtonMargin - kFabGroupSize.height,
        );
        final raw = _offset ?? defaultOffset;
        final clamped = Offset(
          raw.dx.clamp(minX, maxX),
          raw.dy.clamp(minY, maxY),
        );
        void onOffsetChanged(Offset value) {
          setState(() => _offset = Offset(
                value.dx.clamp(minX, maxX),
                value.dy.clamp(minY, maxY),
              ));
        }
        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: clamped.dx,
                top: clamped.dy,
                child: DraggableFabGroup(
                  offset: clamped,
                  onOffsetChanged: onOffsetChanged,
                  snapLeftX: minX,
                  snapRightX: maxX,
                  onSnapEnd: widget.onSnapEnd,
                  child: widget.fabChild,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _tabs = ['/home', '/transactions', '/statistics', '/settings'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  Offset? _fabOffset;

  bool get _isHomeOrStatistics {
    final index = _currentIndex(context);
    return index == 0 || index == 2;
  }

  @override
  void initState() {
    super.initState();
    _loadFabOffset();
  }

  Future<void> _loadFabOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final dx = prefs.getDouble(_keyFabGroupDx);
    final dy = prefs.getDouble(_keyFabGroupDy);
    if (mounted && dx != null && dy != null) {
      setState(() => _fabOffset = Offset(dx, dy));
    }
  }

  void _onFabSnapEnd(Offset finalOffset) {
    setState(() => _fabOffset = finalOffset);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setDouble(_keyFabGroupDx, finalOffset.dx);
      prefs.setDouble(_keyFabGroupDy, finalOffset.dy);
    });
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final location = GoRouterState.of(context).uri.path;
    final isTransactionPage = location.startsWith('/transactions');
    final hideOnHomeAndStats = ref.watch(hideFabOnHomeAndStatsProvider);
    final isStatistics = index == 2;
    final showFab = index < 3 &&
        !isTransactionPage &&
        !isStatistics &&
        !(_isHomeOrStatistics && hideOnHomeAndStats);
    final useDraggableFab = showFab && _isHomeOrStatistics;

    // Draggable FAB: overlay holds offset so setState during drag only rebuilds overlay, not page.
    final body = useDraggableFab
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              _DraggableFabOverlay(
                initialOffset: _fabOffset,
                onSnapEnd: _onFabSnapEnd,
                fabChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AnimatedVoiceFab(),
                    const SizedBox(height: AppSpacing.sm),
                    OpenContainer<void>(
                      transitionDuration: AppDuration.pageTransition,
                      openBuilder: (context, _) =>
                          const TransactionFormScreen(),
                      closedElevation: 2,
                      closedShape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.cardAll,
                      ),
                      closedColor: AppColors.brandPrimary,
                      closedBuilder: (context, openContainer) {
                        return const SizedBox(
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
            ],
          )
        : widget.child;

    return Scaffold(
      body: body,
      floatingActionButton: showFab && !useDraggableFab
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AnimatedVoiceFab(),
                const SizedBox(height: AppSpacing.sm),
                OpenContainer<void>(
                  transitionDuration: AppDuration.pageTransition,
                  openBuilder: (context, _) =>
                      const TransactionFormScreen(),
                  closedElevation: 2,
                  closedShape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.cardAll,
                  ),
                  closedColor: AppColors.brandPrimary,
                  closedBuilder: (context, openContainer) {
                    return const SizedBox(
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
