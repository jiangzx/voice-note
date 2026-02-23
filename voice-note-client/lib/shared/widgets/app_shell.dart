import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../features/settings/presentation/providers/home_fab_preference_provider.dart';
import '../../features/transaction/presentation/screens/transaction_form_screen.dart';
import 'animated_voice_fab.dart';
import 'draggable_fab_group.dart';
import 'home_voice_pill.dart';

/// FAB group size: width 56, height 56+8+56=120.
const Size kFabGroupSize = Size(56, 120);

/// Bottom offset for home pill (dp from safe bottom).
const double kHomePillBottomDp = 20.0;

/// Draggable overlay for home pill: free position, clamp in bounds, persist on drag end.
class _DraggablePillOverlay extends StatefulWidget {
  const _DraggablePillOverlay({
    required this.initialOffset,
    required this.pillBottomWithSafe,
    required this.onDragEnd,
  });

  final Offset? initialOffset;
  final double pillBottomWithSafe;
  final void Function(Offset) onDragEnd;

  @override
  State<_DraggablePillOverlay> createState() => _DraggablePillOverlayState();
}

class _DraggablePillOverlayState extends State<_DraggablePillOverlay> {
  Offset? _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset;
  }

  @override
  void didUpdateWidget(_DraggablePillOverlay oldWidget) {
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
        final pillWidth = homePillWidthForScreen(w);
        const pillHeight = kHomePillHeight;
        const minX = 0.0;
        final maxX = (w - pillWidth).clamp(0.0, double.infinity);
        const minY = 0.0;
        final maxY = (h - pillHeight).clamp(0.0, double.infinity);
        final defaultOffset = Offset(
          (w - pillWidth) / 2,
          h - widget.pillBottomWithSafe - pillHeight,
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
        void onSnapEnd(Offset value) {
          final c = Offset(
            value.dx.clamp(minX, maxX),
            value.dy.clamp(minY, maxY),
          );
          widget.onDragEnd(c);
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
                  snapLeftX: null,
                  snapRightX: null,
                  onSnapEnd: onSnapEnd,
                  child: const HomeVoicePill(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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
  
  // 操作栏高度常量（底部导航已移除）
  static const double _actionBarHeight = 100.0; // 操作栏高度（padding 24px + SafeArea + 内容48px）

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double endX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.minInsets.right -
        kFloatingActionButtonMargin -
        _fabWidth;

    final double borderLineY = scaffoldGeometry.contentBottom -
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
  int _currentIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/home')) return 0;
    if (path.startsWith('/transactions')) return 1;
    if (path.startsWith('/statistics')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0;
  }

  bool get _isHomeOrStatistics {
    final index = _currentIndex(context);
    return index == 0 || index == 2;
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

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final pillBottomWithSafe = bottomPadding + kHomePillBottomDp;
    final savedPillOffset = useDraggableFab
        ? ref.watch(homePillOffsetProvider)
        : null;

    final body = useDraggableFab
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              Positioned.fill(
                child: _DraggablePillOverlay(
                  initialOffset: savedPillOffset,
                  pillBottomWithSafe: pillBottomWithSafe,
                  onDragEnd: (offset) =>
                      ref.read(homePillOffsetProvider.notifier).setOffset(offset),
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
                  closedColor: Theme.of(context).colorScheme.primary,
                  closedBuilder: (context, openContainer) {
                    return SizedBox(
                      height: 56,
                      width: 56,
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: Theme.of(context).colorScheme.onPrimary,
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
    );
  }
}
