import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/design_tokens.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(voiceSessionProvider.notifier).startSession();
      _showTutorialIfNeeded();
      _sessionSubscription = ref.listenManual(
        voiceSessionProvider,
        _onSessionChanged,
      );
    });
  }

  void _onSessionChanged(VoiceSessionState? prev, VoiceSessionState next) {
    if (prev == null) return;
    if (next.messages.length <= prev.messages.length) return;
    final latest = next.messages.last;
    if (latest.type != ChatMessageType.success &&
        latest.type != ChatMessageType.error) {
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    final isSuccess = latest.type == ChatMessageType.success;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.error_rounded,
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
        duration: Duration(milliseconds: isSuccess ? 1500 : 3000),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
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
    final messages = ref.watch(
      voiceSessionProvider.select((s) => s.messages),
    );
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

                  if (isProcessing)
                    _buildProcessingIndicator(),

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
            // Position: right edge, directly below FAB center
            if (voiceState != VoiceState.confirming)
              Positioned(
                right: MediaQuery.of(context).padding.right + 
                       16 + // kFloatingActionButtonMargin
                       (100 - 40) / 2, // Center toggle button horizontally with FAB (FAB width - toggle width) / 2
                top: MediaQuery.of(context).padding.top + 
                     kToolbarHeight + // AppBar height
                     (MediaQuery.of(context).size.height - 
                      MediaQuery.of(context).padding.top - 
                      MediaQuery.of(context).padding.bottom - 
                      kToolbarHeight) / 2 + 
                     28 + // Half of FAB height (56/2) to get FAB bottom
                     AppSpacing.sm, // Spacing between FAB and toggle button
                child: const VoiceExitFabToggleButton(),
              ),
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
        color: theme.colorScheme.errorContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: AppIconSize.sm,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '离线模式 — 仅本地识别',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
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
              color: Theme.of(context).colorScheme.primary,
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
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '正在解析...',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
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
                  decoration: const InputDecoration(
                    hintText: '输入记账内容，如"午餐42块"',
                    border: OutlineInputBorder(),
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
    '午饭', '晚饭', '早餐', '打车', '地铁', '咖啡',
    '奶茶', '水果', '超市', '外卖', '话费', '工资',
  ];

  void _onTextSubmit(String text) {
    if (text.trim().isEmpty) return;
    ref.read(voiceSessionProvider.notifier).submitTextInput(text.trim());
    _textController.clear();
  }

  Widget _buildVoiceControls(VoiceState voiceState, VoiceInputMode inputMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inputMode == VoiceInputMode.pushToTalk)
            _buildPushToTalkButton(voiceState)
          else
            VoiceAnimationWidget(state: voiceState),
          const SizedBox(height: AppSpacing.lg),
          _buildStatusText(voiceState),
        ],
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
    final theme = Theme.of(context);

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
            color: isActive
                ? theme.colorScheme.error
                : theme.colorScheme.primaryContainer,
          ),
          child: Icon(
            isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
            size: AppIconSize.xl,
            color: isActive
                ? theme.colorScheme.onError
                : theme.colorScheme.onPrimaryContainer,
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
      VoiceState.confirming =>
        isBatch ? '请确认或说出要修改的内容' : '请确认以下信息',
    };

    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
    );
  }
}
