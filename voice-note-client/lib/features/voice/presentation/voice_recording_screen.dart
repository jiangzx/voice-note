import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../shared/widgets/home_fab.dart';
import '../../../shared/widgets/voice_exit_fab_toggle_button.dart';
import '../domain/draft_batch.dart';
import '../domain/parse_result.dart';
import '../domain/voice_state.dart';
import 'providers/quick_suggestions_provider.dart';
import 'providers/voice_session_provider.dart';
import 'providers/voice_settings_provider.dart';
import 'widgets/batch_confirmation_card.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/confirmation_card.dart';
import 'widgets/field_editor.dart';
import 'widgets/mode_switcher.dart';
import 'widgets/voice_animation.dart';
import 'widgets/voice_tutorial_dialog.dart';

/// The main voice recording screen combining all voice UI widgets.
class VoiceRecordingScreen extends ConsumerStatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  ConsumerState<VoiceRecordingScreen> createState() =>
      _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends ConsumerState<VoiceRecordingScreen> {
  final _textController = TextEditingController();
  ProviderSubscription<VoiceSessionState>? _sessionSubscription;
  static const _tutorialSeenKey = 'voice_tutorial_seen';
  bool _hasNavigatedOnTimeout = false;
  final _permissionService = PermissionService();
  bool _hasCheckedPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionAndStart();
      _showTutorialIfNeeded();
      _sessionSubscription = ref.listenManual(
        voiceSessionProvider,
        _onSessionChanged,
      );
    });
  }

  Future<void> _checkPermissionAndStart() async {
    if (_hasCheckedPermission) return;
    _hasCheckedPermission = true;

    final status = await _permissionService.checkMicrophonePermission();
    if (!status.isGranted) {
      if (mounted) {
        _showPermissionRequiredDialog();
      }
      return;
    }

    // iOS: brief delay and recheck so permission state is stable before native capture
    if (Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final recheck =
          await _permissionService.checkMicrophonePermission();
      if (!recheck.isGranted && mounted) {
        _showPermissionRequiredDialog();
        return;
      }
    }

    if (!mounted) return;
    await ref.read(voiceSessionProvider.notifier).startSession();
  }

  void _showPermissionRequiredDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('需要麦克风权限'),
        content: const Text('语音记账功能需要麦克风权限才能使用。请在系统设置中授予麦克风权限。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exitScreen();
            },
            child: const Text('返回'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _permissionService.openAppSettings();
              _exitScreen();
            },
            child: const Text('前往设置'),
          ),
        ],
      ),
    );
  }

  Future<void> _onSessionChanged(
      VoiceSessionState? prev, VoiceSessionState next) async {
    if (prev == null) return;

    // Check for session timeout message in auto mode
    if (next.messages.length > prev.messages.length) {
      final latest = next.messages.last;

      // Handle session timeout: auto-navigate to home in auto mode
      if (latest.type == ChatMessageType.system &&
          latest.text == '长时间无操作，已自动退出' &&
          !_hasNavigatedOnTimeout) {
        final inputMode = ref.read(voiceSettingsProvider).inputMode;
        if (inputMode == VoiceInputMode.auto) {
          _hasNavigatedOnTimeout = true;
          // Delay navigation to let user see the message
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              context.go('/home');
            }
          });
          return;
        }
      }

      // Handle permission error: auto-exit if permission is missing
      if (latest.type == ChatMessageType.error &&
          (latest.text.contains('RECORD_AUDIO permission not granted') ||
              latest.text.contains('麦克风权限未授予'))) {
        if (!mounted) return;
        // Check permission status again
        final status = await _permissionService.checkMicrophonePermission();
        if (!status.isGranted) {
          // Permission still not granted, show dialog and exit
          _showPermissionRequiredDialog();
          return;
        }
      }

      // Handle success/error messages with snackbar
      if (latest.type == ChatMessageType.success ||
          latest.type == ChatMessageType.error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        final isSuccess = latest.type == ChatMessageType.success;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: Colors.white,
                  size: AppIconSize.sm,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(latest.text)),
              ],
            ),
            backgroundColor: isSuccess
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.15,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
            ),
            duration: Duration(milliseconds: isSuccess ? 1500 : 3000),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          ),
        );
      }
    }
  }

  Future<void> _showTutorialIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tutorialSeenKey) == true) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const VoiceTutorialDialog(),
    );
    await prefs.setBool(_tutorialSeenKey, true);
  }

  @override
  void dispose() {
    _sessionSubscription?.close();
    _textController.dispose();
    super.dispose();
  }

  void _exitScreen() {
    ref.read(voiceSessionProvider.notifier).endSession();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(
      voiceSessionProvider.select((s) => s.voiceState),
    );
    final messages = ref.watch(voiceSessionProvider.select((s) => s.messages));
    final isProcessing = ref.watch(
      voiceSessionProvider.select((s) => s.isProcessing),
    );
    final isOffline = ref.watch(
      voiceSessionProvider.select((s) => s.isOffline),
    );
    final interimText = ref.watch(
      voiceSessionProvider.select((s) => s.interimText),
    );
    final parseResult = ref.watch(
      voiceSessionProvider.select((s) => s.parseResult),
    );
    final draftBatch = ref.watch(
      voiceSessionProvider.select((s) => s.draftBatch),
    );
    final inputMode = ref.watch(
      voiceSettingsProvider.select((s) => s.inputMode),
    );

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(voiceSessionProvider.notifier).endSession();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('语音记账'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _exitScreen,
          ),
          actions: [
            if (voiceState == VoiceState.listening ||
                voiceState == VoiceState.recognizing)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Center(
                  child: Icon(
                    Icons.mic_rounded,
                    size: 20,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  if (isOffline) _buildOfflineBanner(),
                  Expanded(child: ChatHistory(messages: messages)),

                  if (voiceState == VoiceState.recognizing &&
                      interimText.isNotEmpty)
                    _buildInterimText(interimText),

                  if (isProcessing) _buildProcessingIndicator(),

                  if (voiceState == VoiceState.confirming) ...[
                    if (draftBatch != null && !draftBatch.isSingleItem)
                      _buildBatchConfirmationCard(draftBatch, isProcessing)
                    else if (parseResult != null)
                      _buildConfirmationCard(voiceState, parseResult),
                  ],

                  if (inputMode == VoiceInputMode.keyboard)
                    _buildKeyboardInput(voiceState, isProcessing)
                  else
                    _buildVoiceControls(voiceState, inputMode),
                  _buildModeSwitcher(inputMode),
                ],
              ),
            ),
            // Exit FAB toggle button positioned below the exit FAB
            // Position: right edge, directly below FAB bottom
            if (voiceState != VoiceState.confirming)
              _buildExitFabTogglePosition(),
          ],
        ),
        floatingActionButton: voiceState == VoiceState.confirming
            ? null
            : const HomeFab(),
        floatingActionButtonLocation: voiceScreenFabLocation,
      ),
    );
  }

  Widget _buildOfflineBanner() {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      label: '网络已断开，当前为离线模式，仅使用本地识别',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        color: AppColors.expense.withValues(alpha: 0.12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: AppIconSize.sm,
              color: AppColors.expense,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '离线模式 — 仅本地识别',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.expense,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterimText(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: AppColors.brandPrimary,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBatchConfirmationCard(DraftBatch batch, bool isProcessing) {
    final notifier = ref.read(voiceSessionProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: BatchConfirmationCard(
        batch: batch,
        isLoading: isProcessing,
        onConfirmItem: (index) => notifier.confirmBatchItem(index),
        onCancelItem: (index) => notifier.cancelBatchItem(index),
        onConfirmAll: () => notifier.confirmAllBatchItems(),
        onCancelAll: () => notifier.cancelAllBatchItems(),
      ),
    );
  }

  Widget _buildConfirmationCard(VoiceState voiceState, ParseResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ConfirmationCard(
        result: result,
        onConfirm: () =>
            ref.read(voiceSessionProvider.notifier).confirmTransaction(),
        onCancel: () =>
            ref.read(voiceSessionProvider.notifier).cancelTransaction(),
        onFieldTap: (field, value) {
          if (field == 'type') {
            ref.read(voiceSessionProvider.notifier).updateField(field, value);
            return;
          }
          if (!mounted) return;
          showFieldEditor(
            context: context,
            ref: ref,
            field: field,
            currentValue: value,
            transactionType: result.type,
            onSave: (f, v) {
              if (!mounted) return;
              ref.read(voiceSessionProvider.notifier).updateField(f, v);
            },
          );
        },
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '正在解析...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPlaceholder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardInput(VoiceState voiceState, bool isProcessing) {
    final disabled = isProcessing || voiceState == VoiceState.confirming;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!disabled) _buildQuickSuggestions(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: !disabled,
                  decoration: InputDecoration(
                    hintText: '输入记账内容，如"午餐42块"',
                    hintStyle: TextStyle(color: AppColors.textPlaceholder),
                    border: OutlineInputBorder(borderRadius: AppRadius.inputAll),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.inputAll,
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: disabled ? null : _onTextSubmit,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Semantics(
                label: '发送',
                button: true,
                child: IconButton.filled(
                  onPressed: disabled
                      ? null
                      : () => _onTextSubmit(_textController.text),
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSuggestions() {
    final suggestionsAsync = ref.watch(quickSuggestionsProvider);
    final suggestions = suggestionsAsync.when(
      data: (data) => data,
      loading: () => _defaultSuggestions,
      error: (_, _) => _defaultSuggestions,
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ActionChip(
            label: Text(suggestion),
            visualDensity: VisualDensity.compact,
            onPressed: () => _onSuggestionTap(suggestion),
          );
        },
      ),
    );
  }

  void _onSuggestionTap(String suggestion) {
    final current = _textController.text;
    if (current.isEmpty) {
      _textController.text = suggestion;
    } else {
      _textController.text = '$current$suggestion';
    }
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
  }

  static const _defaultSuggestions = [
    '午饭',
    '晚饭',
    '早餐',
    '打车',
    '地铁',
    '咖啡',
    '奶茶',
    '水果',
    '超市',
    '外卖',
    '话费',
    '工资',
  ];

  void _onTextSubmit(String text) {
    if (text.trim().isEmpty) return;
    ref.read(voiceSessionProvider.notifier).submitTextInput(text.trim());
    _textController.clear();
  }

  Widget _buildVoiceControls(VoiceState voiceState, VoiceInputMode inputMode) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inputMode == VoiceInputMode.pushToTalk)
          _buildPushToTalkButton(voiceState)
        else
          VoiceAnimationWidget(state: voiceState),
        const SizedBox(height: AppSpacing.lg),
        _buildStatusText(voiceState),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: AppRadius.cardAll,
          boxShadow: AppShadow.card,
        ),
        child: content,
      ),
    );
  }

  Widget _buildModeSwitcher(VoiceInputMode inputMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: ModeSwitcher(
        mode: inputMode,
        onChanged: (mode) =>
            ref.read(voiceSessionProvider.notifier).switchMode(mode),
      ),
    );
  }

  Widget _buildPushToTalkButton(VoiceState voiceState) {
    final isActive = voiceState == VoiceState.recognizing;

    return Semantics(
      button: true,
      label: isActive ? '正在录音，松开停止' : '按住说话',
      child: Listener(
        onPointerDown: (_) {
          HapticFeedback.mediumImpact();
          ref.read(voiceSessionProvider.notifier).pushStart();
        },
        onPointerUp: (_) {
          HapticFeedback.lightImpact();
          ref.read(voiceSessionProvider.notifier).pushEnd();
        },
        onPointerCancel: (_) {
          HapticFeedback.lightImpact();
          ref.read(voiceSessionProvider.notifier).pushEnd();
        },
        child: AnimatedContainer(
          duration: AppDuration.fast,
          width: isActive ? 96 : 80,
          height: isActive ? 96 : 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.expense : AppColors.brandPrimary,
          ),
          child: Icon(
            isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
            size: AppIconSize.xl,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusText(VoiceState voiceState) {
    final batch = ref.read(voiceSessionProvider).draftBatch;
    final isBatch = batch != null && !batch.isSingleItem;
    final text = switch (voiceState) {
      VoiceState.idle => '点击开始',
      VoiceState.listening => '正在聆听...',
      VoiceState.recognizing => '正在识别...',
      VoiceState.confirming => isBatch ? '请确认或说出要修改的内容' : '请确认以下信息',
    };

    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppColors.textPlaceholder,
      ),
    );
  }

  /// Builds the exit FAB toggle button positioned below the exit FAB.
  /// Extracts MediaQuery calculation to avoid repeated calculations in build method.
  Widget _buildExitFabTogglePosition() {
    final mediaQuery = MediaQuery.of(context);
    // Calculate toggle button position: below the exit FAB center
    // FAB is positioned at screen center vertically, toggle should be below FAB bottom
    final top = mediaQuery.padding.top +
        kToolbarHeight + // AppBar height
        (mediaQuery.size.height -
                mediaQuery.padding.top -
                mediaQuery.padding.bottom -
                kToolbarHeight) /
            2 +
        28 + // Half of FAB height (56/2) to get FAB bottom
        AppSpacing.sm; // Spacing between FAB and toggle button

    return Positioned(
      right: mediaQuery.padding.right +
          16 + // kFloatingActionButtonMargin
          (100 - 40) /
              2, // Center toggle button horizontally with FAB (FAB width - toggle width) / 2
      top: top,
      child: const RepaintBoundary(
        child: VoiceExitFabToggleButton(),
      ),
    );
  }
}
