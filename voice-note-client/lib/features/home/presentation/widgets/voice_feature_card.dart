import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/permissions/permission_service.dart';

/// Prominent card promoting voice recording on home. Light design: secondary
/// background, soft shadow, linear icon; tap navigates to voice screen.
class VoiceFeatureCard extends StatefulWidget {
  const VoiceFeatureCard({super.key});

  @override
  State<VoiceFeatureCard> createState() => _VoiceFeatureCardState();
}

class _VoiceFeatureCardState extends State<VoiceFeatureCard>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _arrowController;
  late final Animation<Offset> _arrowAnimation;
  bool _isPressed = false;
  final _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _arrowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _arrowAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.12, 0),
    ).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: AppRadius.cardAll,
            boxShadow: AppShadow.card,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AppRadius.cardAll,
              onTap: () => _handleTap(context),
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              child: AnimatedScale(
                scale: _isPressed ? 0.98 : 1.0,
                duration: AppDuration.fast,
                curve: Curves.easeOut,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Row(
                    children: [
                      RepaintBoundary(
                        child: Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Icon(
                            Icons.mic_rounded,
                            size: AppIconSize.xl,
                            color: AppColors.brandPrimary,
                          ),
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
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '说一句就记好',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: AppIconSize.sm,
                                  color: AppColors.textPlaceholder,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  '试试说：午饭35元',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPlaceholder,
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
                                color: AppColors.backgroundTertiary,
                                borderRadius: AppRadius.cardAll,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    size: AppIconSize.sm,
                                    color: AppColors.textPrimary,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '点击开始',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
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
                          size: AppIconSize.sm,
                          color: AppColors.textPlaceholder,
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
    final status = await _permissionService.checkMicrophonePermission();
    if (status.isGranted) {
      if (context.mounted) context.push('/voice-recording');
      return;
    }
    final requestStatus = await _permissionService.requestMicrophonePermission();
    if (requestStatus.isGranted) {
      if (context.mounted) context.push('/voice-recording');
    } else if (requestStatus.isPermanentlyDenied ||
        await _permissionService.isPermanentlyDenied()) {
      if (context.mounted) _showPermissionDeniedDialog(context);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('需要麦克风权限才能使用语音记账功能'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
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
