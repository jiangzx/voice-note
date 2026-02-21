import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design_tokens.dart';
import '../../../../app/theme.dart';
import '../../../../core/di/network_providers.dart';
import '../../../../core/tts/tts_providers.dart';
import '../../../export/presentation/widgets/export_options_sheet.dart';
import '../../../../shared/widgets/error_state_widget.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../account/presentation/providers/account_providers.dart';
import '../../../voice/presentation/providers/voice_settings_provider.dart';
import '../../../voice/presentation/widgets/mode_switcher.dart';
import '../providers/home_fab_preference_provider.dart';
import '../providers/security_settings_provider.dart';
import '../providers/theme_providers.dart';

/// Settings screen with appearance, account, and category management.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiAccountAsync = ref.watch(multiAccountEnabledProvider);
    final currentMode = ref.watch(themeModeProvider);
    final currentColor = ref.watch(themeColorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // --- Appearance section ---
          const _SectionHeader(title: '外观'),

          // Dark mode toggle
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('深色模式'),
            subtitle: Text(_themeModeLabel(currentMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeModeDialog(context, ref, currentMode),
          ),

          // Theme color selection
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主题色'),
            subtitle: Text(_colorLabel(currentColor)),
            trailing: CircleAvatar(radius: 12, backgroundColor: currentColor),
            onTap: () => _showColorPicker(context, ref, currentColor),
          ),

          const Divider(),

          // --- Account section ---
          const _SectionHeader(title: '数据管理'),

          // Multi-account toggle
          multiAccountAsync.when(
            data: (enabled) => SwitchListTile(
              title: const Text('多账户模式'),
              subtitle: const Text('开启后可管理多个账户'),
              value: enabled,
              onChanged: (val) async {
                final repo = await ref.read(accountRepositoryProvider.future);
                await repo.setMultiAccountEnabled(enabled: val);
                ref.invalidate(multiAccountEnabledProvider);
              },
            ),
            loading: () => ShimmerPlaceholder.listItem(),
            error: (e, st) => ErrorStateWidget(
              message: '加载失败',
              onRetry: () => ref.invalidate(multiAccountEnabledProvider),
            ),
          ),

          // Account management (visible only when multi-account enabled)
          multiAccountAsync.when(
            data: (enabled) {
              if (!enabled) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.account_balance_wallet),
                title: const Text('账户管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/settings/accounts'),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),

          const Divider(),

          // Category management
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('分类管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/categories'),
          ),

          // Budget management
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('预算管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/settings/budget'),
          ),

          // Data export
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('数据导出'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showExportSheet(context),
          ),

          const Divider(),

          // --- Voice input section ---
          const _SectionHeader(title: '语音输入'),

          ListTile(
            leading: const Icon(Icons.mic_rounded),
            title: const Text('默认输入模式'),
            subtitle: Text(
              _inputModeLabel(ref.watch(voiceSettingsProvider).inputMode),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final hideAuto = ref
                  .read(voiceSettingsProvider)
                  .hideAutoVoiceMode;
              final modes = hideAuto
                  ? VoiceInputMode.values
                        .where((m) => m != VoiceInputMode.auto)
                        .toList()
                  : VoiceInputMode.values;
              _showInputModeDialog(
                context,
                ref,
                ref.read(voiceSettingsProvider).inputMode,
                modes,
              );
            },
          ),

          // TTS toggle
          _TtsSettingsSection(),

          const Divider(),

          // --- Preferences section ---
          const _SectionHeader(title: '偏好设置'),

          ListTile(
            leading: const Icon(Icons.dns_rounded),
            title: const Text('服务器地址'),
            subtitle: Text(ref.watch(apiConfigProvider).baseUrl),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showServerUrlDialog(
              context,
              ref,
              ref.read(apiConfigProvider).baseUrl,
            ),
          ),

          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('自动语音停顿时间'),
            subtitle: Text(
              '用于自动语音检测下调整允许的停顿时间。调大可允许说话停顿更久，但语音识别可能会有延迟。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                const SizedBox(width: 24 + AppSpacing.lg),
                const Icon(Icons.timer_outlined, size: 20),
                const SizedBox(width: AppSpacing.sm),
                const Text('停顿时间'),
                Expanded(
                  child: Slider(
                    value: ref
                        .watch(voiceSettingsProvider)
                        .vadSilenceDurationMs
                        .toDouble(),
                    min: vadSilenceDurationMsMin.toDouble(),
                    max: vadSilenceDurationMsMax.toDouble(),
                    divisions:
                        (vadSilenceDurationMsMax - vadSilenceDurationMsMin) ~/
                        100,
                    label:
                        '${ref.watch(voiceSettingsProvider).vadSilenceDurationMs} ms',
                    onChanged: (val) {
                      ref
                          .read(voiceSettingsProvider.notifier)
                          .setVadSilenceDurationMs(val.round());
                    },
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${ref.watch(voiceSettingsProvider).vadSilenceDurationMs} ms',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),

          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('隐藏自动语音检测'),
            subtitle: const Text('开启后，语音记账页面将隐藏自动模式入口'),
            value: ref.watch(voiceSettingsProvider).hideAutoVoiceMode,
            onChanged: (newValue) {
              if (newValue) {
                final inputMode = ref.read(voiceSettingsProvider).inputMode;
                if (inputMode == VoiceInputMode.auto) {
                  _showHideAutoModeBlockedDialog(context);
                  return;
                }
              }
              ref
                  .read(voiceSettingsProvider.notifier)
                  .setHideAutoVoiceMode(newValue);
            },
          ),

          SwitchListTile(
            secondary: const Icon(Icons.do_not_disturb_on_outlined),
            title: const Text('隐藏首页与统计页右下角的悬浮按钮'),
            value: ref.watch(hideFabOnHomeAndStatsProvider),
            onChanged: (newValue) {
              ref
                  .read(hideFabOnHomeAndStatsProvider.notifier)
                  .setHideFabOnHomeAndStats(newValue);
            },
          ),

          const Divider(),

          // --- Security section ---
          const _SectionHeader(title: '安全设置'),

          _SecuritySettingsSection(),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }

  String _colorLabel(Color color) {
    final index = AppThemeColors.presets.indexOf(color);
    if (index >= 0) return AppThemeColors.presetNames[index];
    return '自定义';
  }

  void _showThemeModeDialog(
    BuildContext context,
    WidgetRef ref,
    ThemeMode current,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择深色模式'),
        children: ThemeMode.values.map((mode) {
          final isSelected = mode == current;
          return ListTile(
            title: Text(_themeModeLabel(mode)),
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
            ),
            onTap: () {
              ref.read(themeModeProvider.notifier).setMode(mode);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  String _inputModeLabel(VoiceInputMode mode) {
    return switch (mode) {
      VoiceInputMode.auto => '自动检测',
      VoiceInputMode.pushToTalk => '手动模式',
      VoiceInputMode.keyboard => '键盘输入',
    };
  }

  void _showInputModeDialog(
    BuildContext context,
    WidgetRef ref,
    VoiceInputMode current,
    List<VoiceInputMode> modes,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择默认输入模式'),
        children: modes.map((mode) {
          final isSelected = mode == current;
          return ListTile(
            title: Text(_inputModeLabel(mode)),
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
            ),
            onTap: () {
              ref.read(voiceSettingsProvider.notifier).setInputMode(mode);
              Navigator.pop(ctx);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showExportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ExportOptionsSheet(),
    );
  }

  void _showServerUrlDialog(
    BuildContext context,
    WidgetRef ref,
    String currentUrl,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ServerUrlDialog(initialUrl: currentUrl, ref: ref),
    );
  }

  void _showHideAutoModeBlockedDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('请先将默认输入模式切换为手动模式/键盘模式后，再开启隐藏自动语音模式'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref, Color current) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择主题色'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: List.generate(AppThemeColors.presets.length, (i) {
                final color = AppThemeColors.presets[i];
                final isSelected = color == current;
                return GestureDetector(
                  onTap: () {
                    ref.read(themeColorProvider.notifier).setColor(color);
                    Navigator.pop(ctx);
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: color,
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Dialog with server URL editing and connection test.
class _ServerUrlDialog extends StatefulWidget {
  final String initialUrl;
  final WidgetRef ref;

  const _ServerUrlDialog({required this.initialUrl, required this.ref});

  @override
  State<_ServerUrlDialog> createState() => _ServerUrlDialogState();
}

class _ServerUrlDialogState extends State<_ServerUrlDialog> {
  late final TextEditingController _controller;
  _TestStatus _testStatus = _TestStatus.idle;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() => _testStatus = _TestStatus.testing);
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _testStatus = _TestStatus.failed);
      return;
    }

    final client = widget.ref.read(apiClientProvider);
    final originalUrl = client.baseUrl;
    client.updateBaseUrl(url);

    try {
      final ok = await client.healthCheck();
      if (mounted) {
        setState(
          () => _testStatus = ok ? _TestStatus.success : _TestStatus.failed,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _testStatus = _TestStatus.failed);
    } finally {
      client.updateBaseUrl(originalUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('服务器地址'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'http://localhost:8080',
              labelText: 'URL',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildTestResult(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await widget.ref.read(apiConfigProvider).resetBaseUrl();
            widget.ref.invalidate(apiConfigProvider);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('重置'),
        ),
        OutlinedButton(
          onPressed: _testStatus == _TestStatus.testing
              ? null
              : _testConnection,
          child: _testStatus == _TestStatus.testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('测试连接'),
        ),
        FilledButton(
          onPressed: _testStatus == _TestStatus.success
              ? () async {
                  final url = _controller.text.trim();
                  if (url.isNotEmpty) {
                    await widget.ref.read(apiConfigProvider).setBaseUrl(url);
                    widget.ref.invalidate(apiConfigProvider);
                  }
                  if (context.mounted) Navigator.pop(context);
                }
              : null,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildTestResult() {
    return switch (_testStatus) {
      _TestStatus.idle => const SizedBox.shrink(),
      _TestStatus.testing => const SizedBox.shrink(),
      _TestStatus.success => Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '连接成功',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
      _TestStatus.failed => Row(
        children: [
          Icon(
            Icons.error_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '连接失败',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ),
    };
  }
}

enum _TestStatus { idle, testing, success, failed }

/// Security settings: gesture lock and password lock toggles.
class _SecuritySettingsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securitySettingsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.gesture),
          title: const Text('手势解锁'),
          subtitle: Text(
            security.isGestureLockEnabled ? '已开启手势解锁' : '设置手势图案，保护你的账单隐私',
          ),
          value: security.isGestureLockEnabled,
          onChanged: (value) {
            if (value) {
              context.go('/settings/gesture-set');
            } else {
              context.go('/settings/verify-disable?target=gesture');
            }
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: const Text('密码解锁'),
          subtitle: Text(
            security.isPasswordLockEnabled ? '已开启密码解锁' : '设置数字密码，保护你的账单隐私',
          ),
          value: security.isPasswordLockEnabled,
          onChanged: (value) {
            if (value) {
              context.go('/settings/password-set');
            } else {
              context.go('/settings/verify-disable?target=password');
            }
          },
        ),
      ],
    );
  }
}

/// TTS enable/disable toggle and speech rate slider.
class _TtsSettingsSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TtsSettingsSection> createState() =>
      _TtsSettingsSectionState();
}

class _TtsSettingsSectionState extends ConsumerState<_TtsSettingsSection> {
  bool _ttsEnabled = false;
  double _speechRate = 1.0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final tts = ref.read(ttsServiceProvider);
    await tts.init();
    if (mounted) {
      setState(() {
        _ttsEnabled = tts.enabled;
        _speechRate = tts.speechRate;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_rounded),
          title: const Text('语音播报'),
          subtitle: const Text('语音记账时自动播报结果'),
          value: _ttsEnabled,
          onChanged: (val) async {
            final tts = ref.read(ttsServiceProvider);
            await tts.setEnabled(val);
            setState(() => _ttsEnabled = val);
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              const SizedBox(width: 24 + AppSpacing.lg), // Align with list tile
              const Icon(Icons.speed, size: 20),
              const SizedBox(width: AppSpacing.sm),
              const Text('语速'),
              Expanded(
                child: Slider(
                  value: _speechRate,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${_speechRate.toStringAsFixed(1)}x',
                  onChanged: _ttsEnabled
                      ? (val) {
                          setState(() => _speechRate = val);
                        }
                      : null,
                  onChangeEnd: _ttsEnabled
                      ? (val) async {
                          final tts = ref.read(ttsServiceProvider);
                          await tts.setSpeechRate(val);
                        }
                      : null,
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${_speechRate.toStringAsFixed(1)}x',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
