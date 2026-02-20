import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/design_tokens.dart';
import '../../../../core/permissions/permission_service.dart';

/// Prominent card promoting voice recording feature on home screen.
///
/// Features:
/// - Pulsing animation on microphone icon
/// - Shadow and border highlight animations
/// - Arrow icon with slide animation
/// - Action callout text
/// - Enhanced touch feedback
/// - Clickable card that navigates to voice recording screen
class VoiceFeatureCard extends StatefulWidget {
  const VoiceFeatureCard({super.key});

  @override
  State<VoiceFeatureCard> createState() => _VoiceFeatureCardState();
}

class _VoiceFeatureCardState extends State<VoiceFeatureCard>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _shadowController;
  late final Animation<double> _shadowAnimation;
  late final AnimationController _arrowController;
  late final Animation<Offset> _arrowAnimation;
  bool _isPressed = false;
  final _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    
    // Icon pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Shadow pulse animation (slightly offset phase)
    _shadowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _shadowAnimation = Tween<double>(
      begin: 2.0,
      end: 6.0,
    ).animate(
      CurvedAnimation(
        parent: _shadowController,
        curve: Curves.easeInOut,
      ),
    );

    // Arrow slide animation
    _arrowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _arrowAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.15, 0),
    ).animate(
      CurvedAnimation(
        parent: _arrowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shadowController.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: Listenable.merge([_shadowAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          elevation: _shadowAnimation.value,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdAll,
            side: BorderSide(
              color: colorScheme.tertiary.withOpacity(
                0.3 + (_shadowAnimation.value - 2.0) / 4.0 * 0.2,
              ),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppRadius.mdAll,
              onTap: () => _handleTap(context),
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              splashColor: colorScheme.tertiary.withOpacity(0.2),
              highlightColor: colorScheme.tertiary.withOpacity(0.1),
              child: AnimatedScale(
                scale: _isPressed ? 0.98 : 1.0,
                duration: AppDuration.fast,
                curve: Curves.easeOut,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.mdAll,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.tertiaryContainer,
                        colorScheme.tertiaryContainer.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Icon(
                                Icons.mic_rounded,
                                size: AppIconSize.xl,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '语音记账',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '说一句就记好',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onTertiaryContainer.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: AppIconSize.sm,
                                  color: colorScheme.onTertiaryContainer.withOpacity(0.7),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '试试说：午饭35元',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onTertiaryContainer.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary,
                                borderRadius: AppRadius.mdAll,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    size: AppIconSize.sm,
                                    color: colorScheme.onTertiary,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '点击开始',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onTertiary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      SlideTransition(
                        position: _arrowAnimation,
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: AppIconSize.md,
                          color: colorScheme.onTertiaryContainer.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    // Check current permission status
    final status = await _permissionService.checkMicrophonePermission();

    if (status.isGranted) {
      // Permission already granted, navigate directly
      if (context.mounted) {
        context.push('/voice-recording');
      }
      return;
    }

    // Permission not granted, request it
    final requestStatus = await _permissionService.requestMicrophonePermission();

    if (requestStatus.isGranted) {
      // Permission granted, navigate
      if (context.mounted) {
        context.push('/voice-recording');
      }
    } else if (requestStatus.isPermanentlyDenied ||
        await _permissionService.isPermanentlyDenied()) {
      // Permission permanently denied, show dialog to open settings
      if (context.mounted) {
        _showPermissionDeniedDialog(context);
      }
    } else {
      // Permission denied (but not permanently), show message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要麦克风权限才能使用语音记账功能'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showPermissionDeniedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要麦克风权限'),
        content: const Text('请在系统设置中授予麦克风权限'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _permissionService.openAppSettings();
            },
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }
}
