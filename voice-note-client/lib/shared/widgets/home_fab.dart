import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'fab_visibility_provider.dart';

/// Custom FAB location for voice recording screen.
/// 
/// Positions the FAB at the center of the right edge.
class _VoiceScreenFabLocation extends FloatingActionButtonLocation {
  const _VoiceScreenFabLocation();

  // FAB尺寸常量
  static const double _fabHeight = 56.0;
  static const double _fabWidth = 100.0; // Extended FAB approximate width

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    // X坐标：右侧对齐，考虑SafeArea和边距
    final double endX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.minInsets.right -
        kFloatingActionButtonMargin -
        _fabWidth;

    // Y坐标计算：
    // 将FAB放在屏幕垂直中心位置
    // contentTop是AppBar底部位置
    // contentBottom是Scaffold body的底部位置
    // FAB应该位于垂直中心位置
    final double contentTop = scaffoldGeometry.contentTop;
    final double contentBottom = scaffoldGeometry.contentBottom;
    final double contentCenter = (contentTop + contentBottom) / 2;
    // FAB顶部Y = 中心位置 - FAB高度的一半
    final double fabTopY = contentCenter - (_fabHeight / 2);
    final double endY = fabTopY;

    return Offset(endX, endY);
  }

  @override
  String toString() => 'FloatingActionButtonLocation.voiceScreen';
}

/// Extended floating action button for exiting voice recording screen.
class HomeFab extends ConsumerWidget {
  const HomeFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fabVisible = ref.watch(voiceExitFabVisibilityProvider);

    return AnimatedOpacity(
      opacity: fabVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !fabVisible,
        child: FloatingActionButton.extended(
          heroTag: 'exit_fab',
          onPressed: () => context.go('/home'),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('退出'),
          elevation: 6,
        ),
      ),
    );
  }
}

/// Custom FAB location for voice recording screen.
const voiceScreenFabLocation = _VoiceScreenFabLocation();
