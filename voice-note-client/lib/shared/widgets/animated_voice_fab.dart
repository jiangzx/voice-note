import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/theme.dart';
import '../../core/permissions/permission_service.dart';

/// Floating action button for voice recording with pulsing animation.
class AnimatedVoiceFab extends StatefulWidget {
  const AnimatedVoiceFab({super.key});

  @override
  State<AnimatedVoiceFab> createState() => _AnimatedVoiceFabState();
}

class _AnimatedVoiceFabState extends State<AnimatedVoiceFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  final _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: FloatingActionButton(
              heroTag: 'voice_fab',
              onPressed: () => _handleTap(context),
              backgroundColor: AppColors.brandPrimary,
              child: Icon(
                Icons.mic_rounded,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
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
