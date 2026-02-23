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

/// Enterprise-style settings: grouped cards, compact tiles, neutral palette.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _cardRadius = 12.0;
  static const _cardBorder = Color(0xFFE5E7EB);
  static const _sectionTitleStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textPlaceholder,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiAccountAsync = ref.watch(multiAccountEnabledProvider);
    final currentMode = ref.watch(themeModeProvider);
    final currentColor = ref.watch(themeColorProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text(
          '设置',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm,
            AppSpacing.lg, AppSpacing.xl),
        children: [
          const _SectionHeader(title: '外观', style: _sectionTitleStyle),
          _SettingsCard(
            radius: _cardRadius,
            borderColor: _cardBorder,
            children: [
              _settingsTile(
                context,
                icon: Icons.brightness_6_rounded,
                title: '主题',
                subtitle: _themeModeLabel(currentMode),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showThemeModeDialog(context, ref, currentMode),
              ),
              _divider(),
              _settingsTile(
                context,
                icon: Icons.palette_outlined,
                title: '主题色',
                subtitle: _colorLabel(currentColor),
                trailing: CircleAvatar(
                  radius: 10,
                  backgroundColor: currentColor,
                ),
                onTap: () => _showColorPicker(context, ref, currentColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: '数据管理', style: _sectionTitleStyle),
          _SettingsCard(
            radius: _cardRadius,
            borderColor: _cardBorder,
            children: [
              multiAccountAsync.when(
                data: (enabled) => _switchTile(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: '多账户模式',
                  subtitle: '开启后可管理多个账户',
                  value: enabled,
                  onChanged: (val) async {
                    final repo =
                        await ref.read(accountRepositoryProvider.future);
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
              multiAccountAsync.when(
                data: (enabled) {
                  if (!enabled) return const SizedBox.shrink();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _divider(),
                      _settingsTile(
                        context,
                        icon: Icons.account_balance_wallet_rounded,
                        title: '账户管理',
                        trailing: const Icon(
                            Icons.chevron_right_rounded, size: 20),
                        onTap: () => context.go('/settings/accounts'),
                      ),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
              ),
              _divider(),
              _settingsTile(
                context,
                icon: Icons.category_outlined,
                title: '分类管理',
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => context.go('/settings/categories'),
              ),
              _divider(),
              _settingsTile(
                context,
                icon: Icons.pie_chart_outline_rounded,
                title: '预算管理',
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => context.go('/settings/budget'),
              ),
              _divider(),
              _settingsTile(
                context,
                icon: Icons.file_download_outlined,
                title: '数据导出',
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showExportSheet(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: '语音输入', style: _sectionTitleStyle),
          _SettingsCard(
            radius: _cardRadius,
            borderColor: _cardBorder,
            children: [
              _settingsTile(
                context,
                icon: Icons.mic_rounded,
                title: '默认输入模式',
                subtitle: _inputModeLabel(
                    ref.watch(voiceSettingsProvider).inputMode),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  final hideAuto =
                      ref.read(voiceSettingsProvider).hideAutoVoiceMode;
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
              _divider(),
              const _TtsSettingsSection(compact: true),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: '偏好设置', style: _sectionTitleStyle),
          _SettingsCard(
            radius: _cardRadius,
            borderColor: _cardBorder,
            children: [
              _settingsTile(
                context,
                icon: Icons.dns_rounded,
                title: '服务器地址',
                subtitle: ref.watch(apiConfigProvider).baseUrl,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => _showServerUrlDialog(
                  context,
                  ref,
                  ref.read(apiConfigProvider).baseUrl,
                ),
              ),
              _divider(),
              _vadSliderTile(context, ref),
              _divider(),
              _switchTile(
                context,
                icon: Icons.visibility_off_outlined,
                title: '隐藏自动语音检测',
                subtitle: '语音记账页将隐藏自动模式入口',
                value: ref.watch(voiceSettingsProvider).hideAutoVoiceMode,
                onChanged: (newValue) {
                  if (newValue) {
                    final inputMode =
                        ref.read(voiceSettingsProvider).inputMode;
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
              _divider(),
              _switchTile(
                context,
                icon: Icons.do_not_disturb_on_outlined,
                title: '隐藏首页与统计页悬浮按钮',
                value: ref.watch(hideFabOnHomeAndStatsProvider),
                onChanged: (newValue) {
                  ref
                      .read(hideFabOnHomeAndStatsProvider.notifier)
                      .setHideFabOnHomeAndStats(newValue);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SectionHeader(title: '安全设置', style: _sectionTitleStyle),
          _SettingsCard(
            radius: _cardRadius,
            borderColor: _cardBorder,
            child: const _SecuritySettingsSection(compact: true),
          ),
        ],
      ),
    );
  }

  Widget _settingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textPlaceholder,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _switchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      visualDensity: VisualDensity.compact,
      secondary: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textPlaceholder,
                fontSize: 12,
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 56, endIndent: AppSpacing.md);

  Widget _vadSliderTile(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '自动语音停顿',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Slider(
              value: ref
                  .watch(voiceSettingsProvider)
                  .vadSilenceDurationMs
                  .toDouble(),
              min: vadSilenceDurationMsMin.toDouble(),
              max: vadSilenceDurationMsMax.toDouble(),
              divisions:
                  (vadSilenceDurationMsMax - vadSilenceDurationMsMin) ~/ 100,
              onChanged: (val) {
                ref
                    .read(voiceSettingsProvider.notifier)
                    .setVadSilenceDurationMs(val.round());
              },
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${ref.watch(voiceSettingsProvider).vadSilenceDurationMs} ms',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.textPlaceholder,
              ),
            ),
          ),
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
        title: const Text('选择主题'),
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
  const _SecuritySettingsSection({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securitySettingsProvider);
    final theme = Theme.of(context);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          contentPadding: padding,
          visualDensity: compact ? VisualDensity.compact : null,
          secondary: Icon(
            Icons.gesture_rounded,
            size: compact ? 20 : null,
            color: compact ? AppColors.textSecondary : null,
          ),
          title: Text(
            '手势解锁',
            style: compact
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  )
                : null,
          ),
          subtitle: Text(
            security.isGestureLockEnabled
                ? '已开启手势解锁'
                : '设置手势图案，保护账单隐私',
            style: compact
                ? theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPlaceholder,
                    fontSize: 12,
                  )
                : null,
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
        if (compact)
          const Divider(height: 1, indent: 56, endIndent: AppSpacing.md),
        SwitchListTile(
          contentPadding: padding,
          visualDensity: compact ? VisualDensity.compact : null,
          secondary: Icon(
            Icons.lock_outline_rounded,
            size: compact ? 20 : null,
            color: compact ? AppColors.textSecondary : null,
          ),
          title: Text(
            '密码解锁',
            style: compact
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  )
                : null,
          ),
          subtitle: Text(
            security.isPasswordLockEnabled
                ? '已开启密码解锁'
                : '设置数字密码，保护账单隐私',
            style: compact
                ? theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPlaceholder,
                    fontSize: 12,
                  )
                : null,
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
  const _TtsSettingsSection({this.compact = false});

  final bool compact;

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
      return Padding(
        padding: EdgeInsets.symmetric(
            vertical: widget.compact ? AppSpacing.xs : AppSpacing.md),
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final theme = Theme.of(context);
    final padding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          contentPadding: padding,
          visualDensity: widget.compact ? VisualDensity.compact : null,
          secondary: Icon(
            Icons.volume_up_rounded,
            size: widget.compact ? 20 : null,
            color: widget.compact ? AppColors.textSecondary : null,
          ),
          title: Text(
            '语音播报',
            style: widget.compact
                ? theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  )
                : null,
          ),
          subtitle: widget.compact
              ? Text(
                  '语音记账时自动播报结果',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textPlaceholder,
                    fontSize: 12,
                  ),
                )
              : const Text('语音记账时自动播报结果'),
          value: _ttsEnabled,
          onChanged: (val) async {
            final tts = ref.read(ttsServiceProvider);
            await tts.setEnabled(val);
            setState(() => _ttsEnabled = val);
          },
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? AppSpacing.md : AppSpacing.lg,
            vertical: widget.compact ? AppSpacing.xs : 0,
          ),
          child: Row(
            children: [
              if (!widget.compact) const SizedBox(width: 24 + AppSpacing.lg),
              const Icon(
                Icons.speed_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '语速',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: widget.compact ? 15 : null,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _speechRate,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  onChanged: _ttsEnabled
                      ? (val) => setState(() => _speechRate = val)
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
                width: widget.compact ? 36 : 40,
                child: Text(
                  '${_speechRate.toStringAsFixed(1)}x',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: widget.compact ? 11 : null,
                    color: AppColors.textPlaceholder,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section label above each settings card (compact, uppercase-friendly).
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.style});

  final String title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        title,
        style: style ??
            Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
      ),
    );
  }
}

/// White card container for a group of settings (border, radius, shadow).
class _SettingsCard extends StatelessWidget {
  _SettingsCard({
    required this.radius,
    required this.borderColor,
    this.child,
    this.children,
  }) : assert(child != null || (children != null && children.isNotEmpty));

  final double radius;
  final Color borderColor;
  final Widget? child;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    final content = child != null
        ? child!
        : Column(mainAxisSize: MainAxisSize.min, children: children ?? []);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        boxShadow: AppShadow.card,
      ),
      child: content,
    );
  }
}
