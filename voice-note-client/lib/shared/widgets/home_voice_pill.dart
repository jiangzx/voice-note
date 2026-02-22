import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart' as handler;

import '../../app/design_tokens.dart';
import '../../core/permissions/permission_service.dart';
import '../../features/transaction/presentation/screens/transaction_form_screen.dart';

/// 合并悬浮胶囊：80% 宽、16dp 圆角、渐变、左 + / 中「按住语音记录」/ 右键盘图标；底部距导航栏 20dp 由父级定位。
const _kPillHeight = 56.0;
const _kPillRadius = 16.0;
const _kInnerSpacing = 8.0;
const _kMinTouchSize = 44.0;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('需要麦克风权限才能使用语音记账功能'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pillWidth = width * 0.8;

    return Center(
      child: Container(
        width: pillWidth,
        height: _kPillHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kPillRadius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1677FF), Color(0xFF4096FF)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              offset: Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: _kMinTouchSize,
                height: _kMinTouchSize,
                child: Center(
                  child: OpenContainer<void>(
                    transitionDuration: AppDuration.pageTransition,
                    openBuilder: (_, __) => const TransactionFormScreen(),
                    closedElevation: 0,
                    closedColor: Colors.transparent,
                    closedBuilder: (_, openContainer) => IconButton(
                      onPressed: openContainer,
                      icon: const Icon(Icons.add, color: Colors.white, size: 24),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(_kMinTouchSize, _kMinTouchSize),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _kInnerSpacing),
              Expanded(
                child: InkWell(
                  onTap: _openVoiceRecording,
                  borderRadius: BorderRadius.circular(8),
                  child: const Center(
                    child: Text(
                      '按住语音记录',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _kInnerSpacing),
              SizedBox(
                width: _kMinTouchSize,
                height: _kMinTouchSize,
                child: Center(
                  child: OpenContainer<void>(
                    transitionDuration: AppDuration.pageTransition,
                    openBuilder: (_, __) => const TransactionFormScreen(),
                    closedElevation: 0,
                    closedColor: Colors.transparent,
                    closedBuilder: (_, openContainer) => IconButton(
                      onPressed: openContainer,
                      icon: const Icon(
                        Icons.keyboard_alt_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(_kMinTouchSize, _kMinTouchSize),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
