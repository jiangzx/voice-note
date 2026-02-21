import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../providers/security_settings_provider.dart';
import '../widgets/gesture_lock_pad.dart';

/// Full-screen unlock gate. Used for app unlock (/unlock) and for
/// verify-to-disable (/settings/verify-disable?target=gesture|password).
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({
    super.key,
    this.redirectUri = '/home',
    this.disableTarget,
  });

  final String redirectUri;
  final String? disableTarget;

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  bool _usePassword = false;
  int _failCount = 0;
  String? _errorMessage;
  List<int> _path = [];
  bool _gestureError = false;
  double _opacity = 0;
  bool _isExiting = false;
  bool _auxPressed = false;

  bool get _showPasswordOption {
    final s = ref.read(securitySettingsProvider);
    return s.isGestureLockEnabled && s.isPasswordLockEnabled;
  }

  bool get _showGesture =>
      ref.read(securitySettingsProvider).isGestureLockEnabled && !_usePassword;

  bool get _showPassword =>
      ref.read(securitySettingsProvider).isPasswordLockEnabled &&
      (_usePassword || !ref.read(securitySettingsProvider).isGestureLockEnabled);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacity = 1);
    });
  }

  Future<void> _onGestureVerified(String pattern) async {
    final ok = await ref.read(securitySettingsProvider.notifier).verifyGesture(pattern);
    if (!mounted) return;
    if (ok) {
      _onUnlockSuccess();
    } else {
      _onUnlockFailure();
    }
  }

  Future<void> _onPasswordVerified(String password) async {
    final ok = await ref.read(securitySettingsProvider.notifier).verifyPassword(password);
    if (!mounted) return;
    if (ok) {
      _onUnlockSuccess();
    } else {
      _onUnlockFailure();
    }
  }

  void _onUnlockSuccess() {
    if (widget.disableTarget != null) {
      final notifier = ref.read(securitySettingsProvider.notifier);
      if (widget.disableTarget == 'gesture') {
        notifier.setGestureLockEnabled(false, null);
      } else if (widget.disableTarget == 'password') {
        notifier.setPasswordLockEnabled(false, null);
      }
    } else {
      ref.read(securitySettingsProvider.notifier).setUnlockedThisSession();
    }
    setState(() => _isExiting = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) context.go(widget.redirectUri);
    });
  }

  void _onUnlockFailure() {
    setState(() {
      _failCount++;
      _errorMessage = _showGesture ? '图案错误，请重试' : '解锁失败，请重试';
      if (_failCount >= 5) _errorMessage = '请稍后再试';
      if (_showGesture) _gestureError = true;
    });
    if (_showGesture) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _path = [];
            _gestureError = false;
            _errorMessage = null;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securitySettingsProvider);
    final theme = Theme.of(context);

    if (!security.isLockEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(widget.redirectUri);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _isExiting ? 0 : _opacity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title zone: 24sp bold, 8dp to subtitle, 48dp to pad
                    Text(
                      widget.disableTarget != null
                          ? '验证以关闭'
                          : '请绘制解锁图案',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_errorMessage != null)
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          color: _showGesture && _gestureError
                              ? AppColors.expense
                              : theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      )
                    else
                      const SizedBox(height: 14),
                    const SizedBox(height: 48),
                    // Gesture / password zone
                    if (_showGesture)
                      GestureLockPad(
                        path: _path,
                        isError: _gestureError,
                        onPointTapped: (i) {
                          if (_path.contains(i)) return;
                          setState(() => _path = [..._path, i]);
                        },
                        onPathComplete: () {
                          if (_path.length >= 4) {
                            _onGestureVerified(_path.join(','));
                          }
                        },
                        onGestureStart: (firstNode) {
                          setState(() => _path = firstNode != null ? [firstNode] : []);
                        },
                      )
                    else if (_showPassword)
                      _UnlockPasswordInput(
                        onVerified: _onPasswordVerified,
                      ),
                    const SizedBox(height: 40),
                    // Aux: switch to password (16sp brand, tap 70%)
                    if (_showPasswordOption && _showGesture)
                      GestureDetector(
                        onTapDown: (_) => setState(() => _auxPressed = true),
                        onTapUp: (_) => setState(() => _auxPressed = false),
                        onTapCancel: () => setState(() => _auxPressed = false),
                        onTap: () => setState(() {
                          _usePassword = true;
                          _errorMessage = null;
                          _path = [];
                          _gestureError = false;
                        }),
                        child: Opacity(
                          opacity: _auxPressed ? 0.7 : 1,
                          child: Text(
                            '切换到密码解锁',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      )
                    else if (_showPasswordOption && _showPassword)
                      GestureDetector(
                        onTapDown: (_) => setState(() => _auxPressed = true),
                        onTapUp: (_) => setState(() => _auxPressed = false),
                        onTapCancel: () => setState(() => _auxPressed = false),
                        onTap: () => setState(() {
                          _usePassword = false;
                          _errorMessage = null;
                          _auxPressed = false;
                        }),
                        child: Opacity(
                          opacity: _auxPressed ? 0.7 : 1,
                          child: Text(
                            '切换到手势解锁',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnlockPasswordInput extends StatefulWidget {
  const _UnlockPasswordInput({required this.onVerified});

  final void Function(String password) onVerified;

  @override
  State<_UnlockPasswordInput> createState() => _UnlockPasswordInputState();
}

class _UnlockPasswordInputState extends State<_UnlockPasswordInput> {
  String _password = '';

  void _onDigit(String d) {
    if (_password.length >= 6) return;
    setState(() => _password += d);
    if (_password.length == 6) {
      widget.onVerified(_password);
      setState(() => _password = '');
    }
  }

  void _backspace() {
    if (_password.isEmpty) return;
    setState(() => _password = _password.substring(0, _password.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            6,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gestureNodeStroke, width: 1.5),
                  color: i < _password.length
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _Numpad(
          onDigit: _onDigit,
          onBackspace: _backspace,
        ),
      ],
    );
  }
}

class _Numpad extends StatelessWidget {
  const _Numpad({
    required this.onDigit,
    required this.onBackspace,
  });

  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.lg,
      crossAxisSpacing: AppSpacing.lg,
      childAspectRatio: 1.4,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      children: [
        ...List.generate(9, (i) => _NumpadButton(label: (i + 1).toString(), onPressed: () => onDigit((i + 1).toString()))),
        const SizedBox.shrink(),
        _NumpadButton(label: '0', onPressed: () => onDigit('0')),
        _NumpadButton(icon: Icons.backspace_outlined, onPressed: onBackspace),
      ],
    );
  }
}

class _NumpadButton extends StatelessWidget {
  const _NumpadButton({this.label, this.icon, required this.onPressed});

  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Center(
          child: label != null
              ? Text(label!, style: Theme.of(context).textTheme.headlineSmall)
              : Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
    );
  }
}

