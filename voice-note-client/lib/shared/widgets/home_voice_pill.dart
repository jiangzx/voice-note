import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

import '../../core/permissions/permission_service.dart';
import '../../shared/error_copy.dart';

/// Enterprise-style floating pill: elevated surface, two actions (voice / manual add).
const kHomePillHeight = 52.0;
const _kPillHeight = 52.0;
const _kPillRadius = 12.0;
const _kPillMaxWidth = 280.0;

/// Pill width for a given screen width; used by draggable overlay for clamp.
double homePillWidthForScreen(double screenWidth) =>
    (screenWidth * 0.72).clamp(200.0, _kPillMaxWidth);

class HomeVoicePill extends StatefulWidget {
  const HomeVoicePill({super.key});

  @override
  State<HomeVoicePill> createState() => _HomeVoicePillState();
}

class _HomeVoicePillState extends State<HomeVoicePill> {
  final _permissionService = PermissionService();

  Future<void> _openVoiceRecording() async {
    final status = await _permissionService.checkMicrophonePermission();
    if (status == handler.PermissionStatus.granted && mounted) {
      context.push('/voice-recording');
      return;
    }
    final requestStatus = await _permissionService.requestMicrophonePermission();
    if (requestStatus == handler.PermissionStatus.granted && mounted) {
      context.push('/voice-recording');
    } else if (requestStatus == handler.PermissionStatus.permanentlyDenied ||
        await _permissionService.isPermanentlyDenied()) {
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('需要麦克风权限'),
            content: const Text('请在系统设置中授予麦克风权限'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _permissionService.openAppSettings();
                },
                child: const Text('前往设置'),
              ),
            ],
          ),
        );
      }
    } else if (mounted) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ErrorCopy.recordNoPermission,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
          backgroundColor: colorScheme.errorContainer,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pillWidth = (width * 0.72).clamp(200.0, _kPillMaxWidth);
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: pillWidth,
      height: _kPillHeight,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(_kPillRadius),
          border: Border.all(color: colorScheme.outline, width: 1),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              offset: const Offset(0, 2),
              blurRadius: 8,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.05),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(_kPillRadius),
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionSegment(
                          icon: Icons.mic_none_outlined,
                          label: '语音记账',
                          onTap: _openVoiceRecording,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 24,
                        color: colorScheme.outline,
                      ),
                      Expanded(
                        child: _ActionSegment(
                          icon: Icons.add_circle_outline,
                          label: '手动添加',
                          onTap: () => context.push('/record'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionSegment extends StatelessWidget {
  const _ActionSegment({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kPillRadius - 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
