import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../providers/security_settings_provider.dart';
import '../widgets/gesture_lock_pad.dart';

const int _minPoints = 4;

/// Screen to set gesture lock: draw twice to confirm, then persist via notifier.
class SetGestureScreen extends ConsumerStatefulWidget {
  const SetGestureScreen({super.key});

  @override
  ConsumerState<SetGestureScreen> createState() => _SetGestureScreenState();
}

class _SetGestureScreenState extends ConsumerState<SetGestureScreen> {
  List<int> _currentPath = [];
  List<int>? _firstPattern;
  String _message = '请绘制手势图案（至少连接4个点）';
  bool _gestureError = false;

  void _clearPath() {
    setState(() {
      _currentPath = [];
      if (_firstPattern != null) {
        _firstPattern = null;
        _message = '请绘制手势图案（至少连接4个点）';
      }
    });
  }

  String _patternToString(List<int> pattern) {
    return pattern.join(',');
  }

  void _onPointTapped(int index) {
    if (_currentPath.contains(index)) return;
    setState(() {
      _currentPath = [..._currentPath, index];
    });
  }

  void _onPathComplete() {
    if (_currentPath.length < _minPoints) {
      setState(() {
        _message = '请至少连接$_minPoints个节点';
        _currentPath = [];
      });
      return;
    }

    if (_firstPattern == null) {
      setState(() {
        _firstPattern = List.from(_currentPath);
        _currentPath = [];
        _message = '请再次绘制确认';
        _gestureError = false;
      });
      return;
    }

    final firstStr = _patternToString(_firstPattern!);
    final secondStr = _patternToString(_currentPath);
    if (firstStr != secondStr) {
      setState(() {
        _gestureError = true;
        _message = '两次绘制的手势不一致，请重新设置';
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _currentPath = [];
            _firstPattern = null;
            _gestureError = false;
            _message = '请绘制手势图案（至少连接4个点）';
          });
        }
      });
      return;
    }

    final hashed = SecuritySettings.hashGesturePattern(firstStr);
    ref
        .read(securitySettingsProvider.notifier)
        .setGestureLockEnabled(true, hashed)
        .then((_) {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('设置手势'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: _gestureError
                        ? AppColors.expense
                        : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                GestureLockPad(
                  path: _currentPath,
                  isError: _gestureError,
                  onPointTapped: _onPointTapped,
                  onPathComplete: _onPathComplete,
                  onGestureStart: (firstNode) {
                    setState(() {
                      _currentPath = firstNode != null ? [firstNode] : [];
                    });
                  },
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: _currentPath.isNotEmpty || _firstPattern != null
                      ? _clearPath
                      : null,
                  child: Text(
                    '重置',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: (_currentPath.isNotEmpty || _firstPattern != null)
                          ? AppColors.brandPrimary
                          : AppColors.textPlaceholder,
                    ),
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

