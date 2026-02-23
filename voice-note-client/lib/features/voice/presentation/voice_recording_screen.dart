import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/swipe_back_zone.dart';
import '../../../core/permissions/permission_service.dart';
import '../domain/draft_batch.dart';
import '../domain/parse_result.dart';
import '../domain/voice_state.dart';
import 'providers/quick_suggestions_provider.dart';
import 'providers/voice_session_provider.dart';
import 'providers/voice_settings_provider.dart';
import 'voice_copy.dart';
import 'widgets/batch_confirmation_card.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/confirmation_card.dart';
import 'widgets/field_editor.dart';
import 'widgets/mode_switcher.dart';
import 'widgets/voice_animation.dart';
import 'widgets/voice_recognition_loading.dart';
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

  /// PTT slide-to-cancel: pointer position at down for dy threshold.
  Offset? _pttPointerDownLocal;
  bool _pttInCancelZone = false;
  static const double _kCancelZoneThreshold = 56;

  /// WeChat-style: start recording only after this hold, so tap is no-op.
  static const Duration _kPushStartDelay = Duration(milliseconds: 200);
  /// Hold shorter than this after recording started → show "说话时间太短".
  static const Duration _kShortHoldThreshold = Duration(milliseconds: 600);
  DateTime? _pttRecordingStartedAt;
  Timer? _pttPushStartTimer;

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
      // Preload quick suggestions so first keyboard + tap doesn't run DB on focus.
      ref.read(quickSuggestionsProvider.future).ignore();
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
      final recheck = await _permissionService.checkMicrophonePermission();
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
    VoiceSessionState? prev,
    VoiceSessionState next,
  ) async {
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

      // Success/error only shown in chat (no SnackBar pop-up)
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
    _pttPushStartTimer?.cancel();
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
    final hideAutoVoiceMode = ref.watch(
      voiceSettingsProvider.select((s) => s.hideAutoVoiceMode),
    );
    final effectiveMode = hideAutoVoiceMode && inputMode == VoiceInputMode.auto
        ? VoiceInputMode.pushToTalk
        : inputMode;
    final isRecognizing = ref.watch(
      voiceSessionProvider.select((s) => s.isRecognizing),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) ref.read(voiceSessionProvider.notifier).endSession();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          title: const Text(
            'AI 语音记账',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: _exitScreen,
          ),
          actions: [
            if (voiceState == VoiceState.listening ||
                voiceState == VoiceState.recognizing)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 44),
          ],
        ),
        body: SwipeBackZone(
          onBack: _exitScreen,
          child: Stack(
            children: [
              SafeArea(
              child: Column(
                children: [
                  if (isOffline) _buildOfflineBanner(),
                  Expanded(
                    child: ChatHistory(
                      messages: messages,
                      emptyStateHint: _modeEmptyStateHint(effectiveMode),
                      emptyStateHighlight: effectiveMode ==
                                  VoiceInputMode.pushToTalk ||
                              effectiveMode == VoiceInputMode.keyboard
                          ? VoiceCopy.emptyStateHighlight
                          : null,
                      emptyStateExample: effectiveMode ==
                                  VoiceInputMode.pushToTalk ||
                              effectiveMode == VoiceInputMode.keyboard
                          ? VoiceCopy.modeExampleMultiWithLabel
                          : null,
                    ),
                  ),

                  if (voiceState == VoiceState.recognizing &&
                      interimText.isNotEmpty)
                    _buildInterimText(interimText),

                  if (isProcessing) _buildProcessingIndicator(),

                  if (voiceState == VoiceState.confirming) ...[
                    if (inputMode == VoiceInputMode.auto &&
                        draftBatch != null &&
                        !draftBatch.isSingleItem) ...[
                      _buildAutoModeMultiBanner(),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (draftBatch != null && !draftBatch.isSingleItem)
                      _buildBatchConfirmationCard(draftBatch, isProcessing)
                    else if (parseResult != null)
                      _buildConfirmationCard(voiceState, parseResult),
                  ],

                  if (inputMode == VoiceInputMode.keyboard)
                    _buildKeyboardInput(voiceState, isProcessing)
                  else
                    _buildVoiceControls(voiceState, inputMode, isProcessing),
                  _buildModeSwitcher(effectiveMode, hideAutoVoiceMode),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: isRecognizing
                  ? const VoiceRecognitionLoading(key: ValueKey(true))
                  : const SizedBox.shrink(key: ValueKey(false)),
            ),
          ],
        ),
        ),
        floatingActionButton: null,
      ),
    );
  }

  Widget _buildOfflineBanner() {
    final theme = Theme.of(context);
    final expense = theme.extension<TransactionColors>()?.expense ?? theme.colorScheme.error;
    return Semantics(
      liveRegion: true,
      label: '网络已断开，当前为离线模式，仅使用本地识别',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: expense.withValues(alpha: 0.08),
          border: Border(
            bottom: BorderSide(color: expense.withValues(alpha: 0.2)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 14, color: expense),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '离线模式 — 仅本地识别',
              style: theme.textTheme.labelSmall?.copyWith(
                color: expense,
                fontSize: 11,
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
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontStyle: FontStyle.italic,
          fontSize: 14,
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '正在解析...',
            style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardInput(VoiceState voiceState, bool isProcessing) {
    final disabled = isProcessing || voiceState == VoiceState.confirming;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!disabled) _buildQuickSuggestions(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: !disabled,
                  decoration: InputDecoration(
                    hintText: VoiceCopy.modeHintKeyboard,
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 1.5,
                      ),
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
                  icon: const Icon(Icons.send_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            VoiceCopy.modeExampleMultiWithLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
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
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _onSuggestionTap(suggestion),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                ),
                alignment: Alignment.center,
                child: Text(
                  suggestion,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
            ),
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

  Widget _buildVoiceControls(
    VoiceState voiceState,
    VoiceInputMode inputMode,
    bool isProcessing,
  ) {
    final theme = Theme.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (inputMode == VoiceInputMode.pushToTalk) ...[
          if (voiceState == VoiceState.recognizing)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                _pttInCancelZone
                    ? VoiceCopy.pushToTalkReleaseToCancel
                    : VoiceCopy.pushToTalkSlideUpToCancel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _pttInCancelZone
                      ? (theme.extension<TransactionColors>()?.expense ?? theme.colorScheme.error)
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          _buildPushToTalkButton(voiceState),
        ] else
          VoiceAnimationWidget(state: voiceState, size: 100),
        const SizedBox(height: AppSpacing.md),
        _buildStatusContent(voiceState, inputMode, isProcessing),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: theme.colorScheme.outline),
          boxShadow: AppShadow.card,
        ),
        child: content,
      ),
    );
  }

  /// Renders hint with [highlightSubstring] in primary color and w600 when present.
  Widget _buildHintWithHighlight(
    String fullText,
    String? highlightSubstring,
    TextStyle? baseStyle,
  ) {
    final theme = Theme.of(context);
    final useHighlight = highlightSubstring != null &&
        highlightSubstring.isNotEmpty &&
        fullText.contains(highlightSubstring);
    if (!useHighlight) {
      return Text(
        fullText,
        style: baseStyle,
        textAlign: TextAlign.center,
      );
    }
    final h = highlightSubstring;
    final idx = fullText.indexOf(h);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: fullText.substring(0, idx)),
          TextSpan(
            text: h,
            style: baseStyle?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: fullText.substring(idx + h.length),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatusContent(
    VoiceState voiceState,
    VoiceInputMode inputMode,
    bool isProcessing,
  ) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;
    if (voiceState == VoiceState.idle) {
      return Text(
        VoiceCopy.idleHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      );
    }

    if (voiceState == VoiceState.recognizing) {
      return Text(
        VoiceCopy.mainListening,
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 15,
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    }

    if (voiceState == VoiceState.confirming) {
      final batch = ref.read(voiceSessionProvider).draftBatch;
      final isBatch = batch != null && !batch.isSingleItem;
      final text = isBatch
          ? VoiceCopy.mainConfirmBatch
          : VoiceCopy.mainConfirmSingle;
      return Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      );
    }

    if (voiceState == VoiceState.listening) {
      if (inputMode == VoiceInputMode.pushToTalk) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHintWithHighlight(
              VoiceCopy.modeHintManual,
              VoiceCopy.emptyStateHighlight,
              theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              VoiceCopy.modeExampleMultiWithLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }
      if (isProcessing) {
        return Text(
          VoiceCopy.mainProcessing,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        );
      }
      // Auto mode: one-line hint
      return Text(
        VoiceCopy.modeHintAuto,
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: 15,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    }

    return const SizedBox.shrink();
  }

  String _modeEmptyStateHint(VoiceInputMode mode) {
    return switch (mode) {
      VoiceInputMode.auto => VoiceCopy.modeHintAuto,
      VoiceInputMode.pushToTalk => VoiceCopy.modeHintManual,
      VoiceInputMode.keyboard => VoiceCopy.modeHintKeyboard,
    };
  }

  Widget _buildAutoModeMultiBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                VoiceCopy.autoModeMultiNotSupported,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                    ),
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(voiceSessionProvider.notifier).switchMode(
                      VoiceInputMode.pushToTalk,
                    );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(VoiceCopy.autoModeSwitchBatchCleared),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: const Text('切换手动'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSwitcher(VoiceInputMode displayMode, bool hideAutoMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: ModeSwitcher(
        mode: displayMode,
        onChanged: (newMode) async {
          final oldMode = ref.read(voiceSettingsProvider).inputMode;
          await ref.read(voiceSessionProvider.notifier).switchMode(newMode);
          if (!mounted) return;
          if (oldMode == VoiceInputMode.auto &&
              newMode == VoiceInputMode.keyboard) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(VoiceCopy.modeSwitchHintKeyboard),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        hideAutoMode: hideAutoMode,
      ),
    );
  }

  Widget _buildPushToTalkButton(VoiceState voiceState) {
    final isActive = voiceState == VoiceState.recognizing;
    final showCancel = isActive && _pttInCancelZone;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Recording state uses semantic error (red in light) so light-theme button stays red when pressed.
    final recordingColor = colorScheme.error;
    final primary = colorScheme.primary;
    final onPrimary = colorScheme.onPrimary;
    final onError = colorScheme.onError;

    return Semantics(
      button: true,
      label: isActive
          ? (_pttInCancelZone
              ? VoiceCopy.pushToTalkReleaseToCancel
              : VoiceCopy.pushToTalkReleaseToSend)
          : '按住说话',
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          _pttPointerDownLocal = event.localPosition;
          _pttRecordingStartedAt = null;
          _pttInCancelZone = false;
          _pttPushStartTimer?.cancel();
          _pttPushStartTimer = Timer(_kPushStartDelay, () {
            if (_pttPointerDownLocal == null) return;
            _pttRecordingStartedAt = DateTime.now();
            HapticFeedback.mediumImpact();
            ref.read(voiceSessionProvider.notifier).pushStart();
          });
        },
        onPointerMove: (PointerMoveEvent event) {
          if (_pttPointerDownLocal == null) return;
          final dy = event.localPosition.dy - _pttPointerDownLocal!.dy;
          final inCancelZone = dy < -_kCancelZoneThreshold;
          if (inCancelZone != _pttInCancelZone) {
            setState(() => _pttInCancelZone = inCancelZone);
            HapticFeedback.selectionClick();
          }
        },
        onPointerUp: (PointerUpEvent _) {
          _handlePttRelease();
        },
        onPointerCancel: (PointerCancelEvent _) {
          _handlePttRelease();
        },
        child: AnimatedContainer(
          duration: AppDuration.fast,
          width: isActive ? 88 : 72,
          height: isActive ? 88 : 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? recordingColor : primary,
            boxShadow: [
              BoxShadow(
                color: (isActive ? recordingColor : primary).withValues(alpha: 0.25),
                blurRadius: isActive ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: showCancel
              ? Icon(Icons.cancel_outlined, size: AppIconSize.lg, color: onError)
              : isActive
                  ? SpeakingWaveform(size: AppIconSize.lg, color: onError)
                  : Icon(Icons.mic_none_rounded, size: AppIconSize.lg, color: onPrimary),
        ),
      ),
    );
  }

  void _handlePttRelease() {
    final wasCancelZone = _pttInCancelZone;
    final hadPttDown = _pttPointerDownLocal != null;
    final startedAt = _pttRecordingStartedAt;
    _pttPushStartTimer?.cancel();
    _pttPushStartTimer = null;
    _pttPointerDownLocal = null;
    _pttRecordingStartedAt = null;
    setState(() => _pttInCancelZone = false);
    if (!hadPttDown) return;
    // Tap (released before delay): no feedback, no recognition.
    if (startedAt == null) return;
    HapticFeedback.lightImpact();
    if (wasCancelZone) {
      ref.read(voiceSessionProvider.notifier).pushCancel();
      return;
    }
    final holdDuration = DateTime.now().difference(startedAt);
    if (holdDuration < _kShortHoldThreshold) {
      ref.read(voiceSessionProvider.notifier).pushCancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(VoiceCopy.pushToTalkTooShort),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ref.read(voiceSessionProvider.notifier).pushEnd();
    }
  }
}
