import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../providers/security_settings_provider.dart';

const int _passwordLength = 6;

/// Screen to set password lock: enter 6 digits twice to confirm, then persist.
class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  String _firstPassword = '';
  String _currentPassword = '';
  String _message = '请设置6位数字密码';

  void _clearInput() {
    setState(() {
      _currentPassword = '';
      if (_firstPassword.isNotEmpty) {
        _firstPassword = '';
        _message = '请设置6位数字密码';
      }
    });
  }

  void _appendDigit(String digit) {
    if (_currentPassword.length >= _passwordLength) return;
    setState(() {
      _currentPassword += digit;
      if (_currentPassword.length == _passwordLength) {
        if (_firstPassword.isEmpty) {
          _firstPassword = _currentPassword;
          _currentPassword = '';
          _message = '请再次输入确认';
        } else {
          if (_firstPassword != _currentPassword) {
            _message = '两次输入的密码不一致，请重新设置';
            _currentPassword = '';
            _firstPassword = '';
          } else {
            final hashed = SecuritySettings.hashPassword(_currentPassword);
            ref
                .read(securitySettingsProvider.notifier)
                .setPasswordLockEnabled(true, hashed)
                .then((_) {
              if (mounted) context.pop();
            });
          }
        }
      }
    });
  }

  void _backspace() {
    if (_currentPassword.isEmpty) return;
    setState(() => _currentPassword = _currentPassword.substring(0, _currentPassword.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置密码'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Text(
                _message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _PasswordDots(length: _currentPassword.length),
              const SizedBox(height: AppSpacing.xxl),
              TextButton.icon(
                onPressed: _currentPassword.isNotEmpty || _firstPassword.isNotEmpty
                    ? _clearInput
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('重置'),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _Numpad(
                  onDigit: _appendDigit,
                  onBackspace: _backspace,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordDots extends StatelessWidget {
  const _PasswordDots({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _passwordLength,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gestureNodeStroke,
                width: 1.5,
              ),
              color: i < length
                  ? theme.colorScheme.primary
                  : Colors.transparent,
            ),
          ),
        ),
      ),
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
        ...List.generate(9, (i) {
          final n = (i + 1).toString();
          return _NumpadButton(
            label: n,
            onPressed: () => onDigit(n),
          );
        }),
        const SizedBox.shrink(),
        _NumpadButton(
          label: '0',
          onPressed: () => onDigit('0'),
        ),
        _NumpadButton(
          icon: Icons.backspace_outlined,
          onPressed: onBackspace,
        ),
      ],
    );
  }
}

class _NumpadButton extends StatelessWidget {
  const _NumpadButton({
    this.label,
    this.icon,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                )
              : Icon(icon, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}
