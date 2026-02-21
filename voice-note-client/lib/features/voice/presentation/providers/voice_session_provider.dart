import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/audio/audio_session_providers.dart';
import '../../../../core/audio/native_audio_models.dart';
import '../../../../core/di/network_providers.dart';
import '../../../../core/tts/tts_templates.dart';
import '../../../budget/domain/budget_service.dart';
import '../../../budget/presentation/providers/budget_providers.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/providers/transaction_query_providers.dart';
import '../../domain/draft_batch.dart';
import '../../domain/parse_result.dart';
import '../../domain/voice_orchestrator.dart';
import '../../domain/voice_state.dart';
import '../helpers/transaction_save_helper.dart';
import '../voice_copy.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/mode_switcher.dart';
import 'quick_suggestions_provider.dart';
import 'voice_providers.dart';
import 'voice_settings_provider.dart';

/// Immutable state of an active voice recording session.
class VoiceSessionState {
  final VoiceState voiceState;
  final String interimText;
  final ParseResult? parseResult;
  final DraftBatch? draftBatch;
  final List<ChatMessage> messages;
  final String? errorMessage;
  final bool isOffline;

  /// True while NLP is parsing text (between submit and result).
  final bool isProcessing;

  /// True while waiting for ASR/NLP after user finished speaking (show recognition loading overlay).
  final bool isRecognizing;

  const VoiceSessionState({
    this.voiceState = VoiceState.idle,
    this.interimText = '',
    this.parseResult,
    this.draftBatch,
    this.messages = const [],
    this.errorMessage,
    this.isOffline = false,
    this.isProcessing = false,
    this.isRecognizing = false,
  });

  VoiceSessionState copyWith({
    VoiceState? voiceState,
    String? interimText,
    ParseResult? parseResult,
    DraftBatch? draftBatch,
    List<ChatMessage>? messages,
    String? errorMessage,
    bool? isOffline,
    bool? isProcessing,
    bool? isRecognizing,
    bool clearParseResult = false,
    bool clearError = false,
  }) {
    return VoiceSessionState(
      voiceState: voiceState ?? this.voiceState,
      interimText: interimText ?? this.interimText,
      parseResult: clearParseResult ? null : (parseResult ?? this.parseResult),
      draftBatch: clearParseResult ? null : (draftBatch ?? this.draftBatch),
      messages: messages ?? this.messages,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isOffline: isOffline ?? this.isOffline,
      isProcessing: isProcessing ?? this.isProcessing,
      isRecognizing: isRecognizing ?? this.isRecognizing,
    );
  }
}

/// Manages the voice session lifecycle and delegates hardware control
/// to [VoiceOrchestrator].
///
/// State machine: idle → listening → recognizing → confirming → listening/idle
class VoiceSessionNotifier extends Notifier<VoiceSessionState>
    implements VoiceOrchestratorDelegate {
  VoiceOrchestrator? _orchestrator;
  bool _sessionActive = false;
  StreamSubscription<bool>? _networkSub;
  StreamSubscription<NativeAudioEvent>? _nativeAudioSub;
  TransactionSaveHelper? _saveHelper;
  String? _nativeAudioSessionId;

  /// Serializes auto ↔ pushToTalk mode switches to avoid overlapping stop/start.
  Future<void>? _modeSwitchInFlight;

  /// True while switching audio mode; used to suppress asr_send_error from disconnect.
  bool _modeSwitchInProgress = false;

  static const Duration _recognizingTimeoutDuration = Duration(seconds: 12);
  Timer? _recognizingTimeout;

  void _cancelRecognizingTimeout() {
    _recognizingTimeout?.cancel();
    _recognizingTimeout = null;
  }

  void _startRecognizingTimeout() {
    _cancelRecognizingTimeout();
    _recognizingTimeout = Timer(_recognizingTimeoutDuration, () {
      if (!_sessionActive || !state.isRecognizing) return;
      _recognizingTimeout = null;
      state = state.copyWith(isRecognizing: false);
      _addAssistantMessage(
        VoiceCopy.recognizingTimeout,
        type: ChatMessageType.error,
      );
    });
  }

  @override
  VoiceSessionState build() {
    _sessionActive = false;
    return const VoiceSessionState();
  }

  static const _uuid = Uuid();

  /// Enter voice mode — create orchestrator and start listening.
  Future<void> startSession() async {
    if (kDebugMode) debugPrint('[VoiceInit] === startSession BEGIN ===');
    _orchestrator?.dispose();
    _sessionActive = true;

    final sessionId = _uuid.v4().substring(0, 8);
    _nativeAudioSessionId = sessionId;
    ref.read(apiClientProvider).setSessionId(sessionId);
    dev.log('Session started: $sessionId', name: 'VoiceSession');

    if (kDebugMode)
      debugPrint('[VoiceInit] Step 1: Creating VoiceOrchestrator...');
    final txService = ref.read(voiceTransactionServiceProvider);
    _saveHelper = TransactionSaveHelper(
      persist: (result) => txService.save(result),
      persistBatch: (results) => txService.saveBatch(results),
      invalidateQueries: () {
        ref.invalidate(quickSuggestionsProvider);
        invalidateTransactionQueries(ref);
      },
      checkBudget: _checkBudgetAsyncFromEntity,
    );
    _orchestrator = VoiceOrchestrator(
      asrRepository: ref.read(asrRepositoryProvider),
      nlpOrchestrator: ref.read(nlpOrchestratorProvider),
      correctionHandler: ref.read(voiceCorrectionHandlerProvider),
      delegate: this,
      nativeAudioGateway: ref.read(nativeAudioGatewayProvider),
      nativeAudioSessionId: sessionId,
    );

    final networkService = ref.read(networkStatusServiceProvider);
    final isOffline = !networkService.isOnline;
    if (kDebugMode) debugPrint('[VoiceInit] Network: isOffline=$isOffline');
    state = state.copyWith(
      voiceState: VoiceState.listening,
      isOffline: isOffline,
      clearError: true,
    );

    if (isOffline) {
      _addAssistantMessage('当前处于离线模式，仅使用本地识别', type: ChatMessageType.system);
    }

    _networkSub?.cancel();
    _networkSub = networkService.onStatusChange.listen(_onNetworkChanged);
    await _nativeAudioSub?.cancel();
    _nativeAudioSub = ref
        .read(nativeAudioGatewayProvider)
        .events
        .listen(
          _onNativeAudioEvent,
          onError: (Object error) {
            if (!_sessionActive) return;
            _addAssistantMessage(
              '原生音频事件异常：$error',
              type: ChatMessageType.error,
            );
          },
        );

    final mode = ref.read(voiceSettingsProvider).inputMode;
    if (kDebugMode)
      debugPrint('[VoiceInit] Step 2: Starting listening (mode=$mode)...');
    try {
      await _orchestrator!.startListening(mode);
      if (kDebugMode) debugPrint('[VoiceInit] === startSession COMPLETE ===');
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceInit] startListening FAILED: $e');
      if (!_sessionActive) return;
      state = state.copyWith(errorMessage: '$e', voiceState: VoiceState.idle);
      _addAssistantMessage('启动失败：$e', type: ChatMessageType.error);
    }
  }

  /// Process text input from keyboard mode.
  ///
  /// Note: user message is added by [onFinalText] callback from orchestrator,
  /// NOT here, to avoid duplicates.
  /// Auto-restarts session if it was ended (e.g. by inactivity timeout).
  Future<void> submitTextInput(String text) async {
    if (_orchestrator == null) {
      await startSession();
      if (_orchestrator == null) {
        _addAssistantMessage('会话未就绪，请重试', type: ChatMessageType.error);
        return;
      }
    }
    state = state.copyWith(isProcessing: true);
    try {
      await _orchestrator?.processTextInput(text);
    } catch (e) {
      if (!_sessionActive) return;
      _addAssistantMessage('处理失败：$e', type: ChatMessageType.error);
    } finally {
      if (_sessionActive) state = state.copyWith(isProcessing: false);
    }
  }

  /// Switch voice input mode, managing audio lifecycle accordingly.
  Future<void> switchMode(VoiceInputMode newMode) async {
    final settings = ref.read(voiceSettingsProvider.notifier);
    final oldMode = ref.read(voiceSettingsProvider).inputMode;
    settings.setInputMode(newMode);

    if (oldMode == newMode) return;

    final isAudioMode =
        newMode == VoiceInputMode.auto || newMode == VoiceInputMode.pushToTalk;
    final wasAudioMode =
        oldMode == VoiceInputMode.auto || oldMode == VoiceInputMode.pushToTalk;

    if (wasAudioMode && newMode == VoiceInputMode.keyboard) {
      // Switching to keyboard — release mic and VAD
      await _orchestrator?.stopListening();
      state = state.copyWith(voiceState: VoiceState.listening);
      if (_sessionActive) {
        _addAssistantMessage(
          _inputModeSwitchMessage(newMode),
          type: ChatMessageType.system,
        );
      }
    } else if (!wasAudioMode && isAudioMode) {
      // Switching from keyboard to audio mode — restart audio
      try {
        await _orchestrator?.startListening(newMode);
        state = state.copyWith(voiceState: VoiceState.listening);
        if (_sessionActive) {
          _addAssistantMessage(
            _inputModeSwitchMessage(newMode),
            type: ChatMessageType.system,
          );
        }
      } catch (e) {
        if (!_sessionActive) return;
        _addAssistantMessage('启动麦克风失败：$e', type: ChatMessageType.error);
      }
    } else if (wasAudioMode && isAudioMode) {
      await _modeSwitchInFlight;
      final completer = Completer<void>();
      _modeSwitchInFlight = completer.future;
      _modeSwitchInProgress = true;
      try {
        await _orchestrator?.switchInputMode(newMode, previousMode: oldMode);
        if (_sessionActive) {
          _addAssistantMessage(
            _inputModeSwitchMessage(newMode),
            type: ChatMessageType.system,
          );
        }
      } catch (e) {
        if (!_sessionActive) return;
        settings.setInputMode(oldMode);
        _addAssistantMessage('切换模式失败，请检查网络后重试', type: ChatMessageType.error);
      } finally {
        _modeSwitchInProgress = false;
        completer.complete();
        _modeSwitchInFlight = null;
      }
    }
  }

  /// Push-to-talk: start recording.
  /// Auto-restarts session if it was ended (e.g. by inactivity timeout).
  Future<void> pushStart() async {
    if (_orchestrator == null) {
      await startSession();
      if (_orchestrator == null) {
        _addAssistantMessage('会话未就绪，请重试', type: ChatMessageType.error);
        return;
      }
    }
    try {
      await _orchestrator?.pushStart();
    } catch (e) {
      if (!_sessionActive) return;
      _addAssistantMessage('录音启动失败：$e', type: ChatMessageType.error);
    }
  }

  /// Push-to-talk: stop recording.
  Future<void> pushEnd() async {
    state = state.copyWith(isRecognizing: true);
    _startRecognizingTimeout();
    await _orchestrator?.pushEnd();
  }

  /// User confirmed the transaction — save to DB and continue listening.
  Future<void> confirmTransaction() async {
    final result = state.parseResult;
    if (result == null) return;

    await _orchestrator?.stopTtsIfPlaying();

    try {
      await _saveHelper?.saveOne(result);
      HapticFeedback.heavyImpact();
      final amountStr = result.amount != null
          ? result.amount! == result.amount!.roundToDouble()
                ? result.amount!.toInt().toString()
                : result.amount!.toStringAsFixed(2)
          : '--';
      _addAssistantMessage(
        VoiceCopy.successFeedback(
          category: result.category,
          typeLabel: _typeLabel(result.type),
          amountStr: amountStr,
        ),
        type: ChatMessageType.success,
      );
    } catch (e) {
      HapticFeedback.vibrate();
      _addAssistantMessage('保存失败：$e', type: ChatMessageType.error);
    }
    // Clear orchestrator's internal draftBatch to ensure subsequent input
    // is treated as new input, not correction
    _orchestrator?.clearDraftBatch();
    state = state.copyWith(
      voiceState: VoiceState.listening,
      clearParseResult: true,
    );
    final inputMode = ref.read(voiceSettingsProvider).inputMode;
    if (inputMode == VoiceInputMode.auto) {
      _orchestrator?.speakAndResumeTimer(TtsTemplates.saved());
    } else {
      _orchestrator?.resumeTimer();
    }
  }

  /// Update a single field on the current parse result.
  void updateField(String field, dynamic value) {
    final current = state.parseResult;
    if (current == null) return;

    final updated = switch (field) {
      'amount' => current.copyWith(amount: value as double),
      'category' => current.copyWith(category: value as String),
      'date' => current.copyWith(date: value as String),
      'account' => current.copyWith(account: value as String),
      'description' => current.copyWith(description: value as String),
      'type' => current.copyWith(type: value as String),
      _ => current,
    };
    state = state.copyWith(parseResult: updated);
  }

  /// Confirm a specific item in the current batch by index.
  void confirmBatchItem(int index) {
    final batch = state.draftBatch;
    if (batch == null) return;
    _orchestrator?.processTextInput('确认第${index + 1}笔');
  }

  /// Cancel a specific item in the current batch by index.
  void cancelBatchItem(int index) {
    final batch = state.draftBatch;
    if (batch == null) return;
    _orchestrator?.processTextInput('取消第${index + 1}笔');
  }

  /// Confirm all pending items in the current batch.
  void confirmAllBatchItems() {
    _orchestrator?.processTextInput('确认');
  }

  /// Cancel all pending items in the current batch.
  void cancelAllBatchItems() {
    _orchestrator?.processTextInput('取消');
  }

  /// User cancelled the current transaction.
  /// Stops TTS first so cancel does not leave playback running.
  Future<void> cancelTransaction() async {
    await _orchestrator?.stopTtsIfPlaying();
    _addAssistantMessage(VoiceCopy.feedbackCancel);
    // Clear orchestrator state so next ASR is treated as new input, not correction.
    _orchestrator?.clearDraftBatch();
    state = state.copyWith(
      voiceState: VoiceState.listening,
      clearParseResult: true,
    );
  }

  /// Exit voice mode entirely — dispose orchestrator.
  Future<void> endSession() async {
    _sessionActive = false;
    _cancelRecognizingTimeout();
    _networkSub?.cancel();
    _networkSub = null;
    _nativeAudioSub?.cancel();
    _nativeAudioSub = null;
    _nativeAudioSessionId = null;
    final orch = _orchestrator;
    _orchestrator = null;
    await orch?.dispose();
    _saveHelper?.clear();
    _saveHelper = null;
    ref.read(apiClientProvider).clearSessionId();
    dev.log('Session ended', name: 'VoiceSession');
    state = const VoiceSessionState();
  }

  void _onNetworkChanged(bool isOnline) {
    if (!_sessionActive) return;
    state = state.copyWith(isOffline: !isOnline);
    if (!isOnline) {
      _addAssistantMessage('网络已断开，切换到离线模式', type: ChatMessageType.system);
    } else {
      _addAssistantMessage('网络已恢复，AI 识别可用', type: ChatMessageType.system);
    }
  }

  static String _inputModeSwitchMessage(VoiceInputMode mode) {
    final label = switch (mode) {
      VoiceInputMode.auto => '自动',
      VoiceInputMode.pushToTalk => '手动',
      VoiceInputMode.keyboard => '键盘',
    };
    return '已切换至$label模式';
  }

  static String _typeLabel(String type) => switch (type.toUpperCase()) {
    'EXPENSE' => '支出',
    'INCOME' => '收入',
    'TRANSFER' => '转账',
    _ => '支出',
  };

  void _onNativeAudioEvent(NativeAudioEvent event) {
    if (!_sessionActive) return;
    if (_nativeAudioSessionId == null ||
        event.sessionId != _nativeAudioSessionId) {
      return;
    }

    if (event.event == 'audioRouteChanged') {
      return;
    }

    if (event.event == 'audioFocusChanged') {
      return;
    }

    if (event.event == 'bargeInTriggered') {
      HapticFeedback.lightImpact();
      state = state.copyWith(voiceState: VoiceState.recognizing);
      return;
    }

    if (event.event == 'runtimeError' && event.error != null) {
      final errorMessage = event.error!.message;
      if (errorMessage.contains('error committing input audio buffer') ||
          errorMessage.contains('maybe no invalid audio stream') ||
          errorMessage.contains('no audio')) {
        return;
      }
      if (_modeSwitchInProgress && errorMessage.contains('asr_send_error')) {
        if (kDebugMode) {
          debugPrint(
            '[VoiceSession] Suppressing asr_send_error during mode switch',
          );
        }
        return;
      }
      // Same as orchestrator: suppress teardown send errors (arrive after mode switch clears flag).
      if (errorMessage.startsWith('asr_send_error:') &&
          (errorMessage.contains('cancelled') ||
              errorMessage.contains('canceled'))) {
        if (kDebugMode) {
          debugPrint(
            '[VoiceSession] Suppressing benign asr_send_error (teardown): $errorMessage',
          );
        }
        return;
      }
      _addAssistantMessage('原生音频错误：$errorMessage', type: ChatMessageType.error);
    }
  }

  // ======================== VoiceOrchestratorDelegate ========================

  @override
  void onSpeechDetected() {
    if (!_sessionActive) return;
    HapticFeedback.lightImpact();
    state = state.copyWith(voiceState: VoiceState.recognizing, interimText: '');
  }

  @override
  void onStateChanged(VoiceState newState) {
    if (!_sessionActive) return;
    state = state.copyWith(voiceState: newState);
  }

  @override
  void onRecognizingStarted() {
    if (!_sessionActive) return;
    state = state.copyWith(isRecognizing: true);
    _startRecognizingTimeout();
  }

  @override
  void onInterimText(String text) {
    if (!_sessionActive) return;
    state = state.copyWith(interimText: text);
  }

  @override
  void onFinalText(String text, DraftBatch draftBatch) {
    if (!_sessionActive) return;
    _cancelRecognizingTimeout();
    state = state.copyWith(isRecognizing: false);
    HapticFeedback.mediumImpact();
    _addUserMessage(text);
    final result = draftBatch.items.isNotEmpty
        ? draftBatch.items.first.result
        : null;
    // If DraftBatch is empty, do not enter confirming state, stay in listening state
    if (draftBatch.items.isEmpty) {
      state = state.copyWith(
        voiceState: VoiceState.listening,
        interimText: '',
        parseResult: null,
        draftBatch: null,
        isProcessing: false, // 立即设置 isProcessing = false，避免显示"正在解析"并block输入框
      );
    } else {
      state = state.copyWith(
        voiceState: VoiceState.confirming,
        interimText: '',
        parseResult: result,
        draftBatch: draftBatch,
        isProcessing: false, // 解析完成，设置 isProcessing = false
      );
    }
  }

  @override
  void onDraftBatchUpdated(DraftBatch draftBatch) {
    if (!_sessionActive) return;
    final result = draftBatch.pendingItems.isNotEmpty
        ? draftBatch.pendingItems.first.result
        : null;
    state = state.copyWith(parseResult: result, draftBatch: draftBatch);
  }

  @override
  void onBatchSaved(List<DraftTransaction> confirmedItems) {
    if (!_sessionActive) return;
    _saveBatch(confirmedItems);
    // 显示成功提示
    if (confirmedItems.length == 1) {
      final result = confirmedItems.first.result;
      HapticFeedback.heavyImpact();
      _addAssistantMessage(
        '已记录 ¥${result.amount?.toStringAsFixed(2) ?? "--"}'
        '${result.category != null ? " · ${result.category}" : ""}',
        type: ChatMessageType.success,
      );
    } else if (confirmedItems.length > 1) {
      HapticFeedback.heavyImpact();
      _addAssistantMessage(
        '已记录 ${confirmedItems.length} 笔交易',
        type: ChatMessageType.success,
      );
    }
  }

  Future<void> _saveBatch(List<DraftTransaction> items) async {
    final result = await _saveHelper?.saveBatch(items);
    if (result != null && result.hasErrors) {
      _addAssistantMessage(
        '批量保存部分失败：${result.errors.first}',
        type: ChatMessageType.error,
      );
    }
  }

  void onParseResultUpdated(ParseResult result) {
    if (!_sessionActive) return;
    state = state.copyWith(parseResult: result);
  }

  @override
  void onConfirmTransaction() {
    if (!_sessionActive) return;
    // 如果是单笔确认且还没有显示消息，显示成功提示
    // Batch saving is handled by onBatchSaved; this is a UI-only notification.
    final result = state.parseResult;
    if (result != null && state.draftBatch == null) {
      HapticFeedback.heavyImpact();
      _addAssistantMessage(
        '已记录 ¥${result.amount?.toStringAsFixed(2) ?? "--"}'
        '${result.category != null ? " · ${result.category}" : ""}',
        type: ChatMessageType.success,
      );
    }
    state = state.copyWith(
      voiceState: VoiceState.listening,
      clearParseResult: true,
    );
  }

  @override
  void onCancelTransaction() {
    if (!_sessionActive) return;
    cancelTransaction();
  }

  @override
  Future<void> onContinueRecording() async {
    if (!_sessionActive) return;
    // Persisting confirmed items is handled by onBatchSaved.
    state = state.copyWith(
      voiceState: VoiceState.listening,
      clearParseResult: true,
    );
  }

  @override
  void onExitSession() async {
    if (!_sessionActive) return;
    _showSessionSummary();
    await _speakSessionSummary();
    endSession();
  }

  @override
  void onTimeoutWarning() {
    if (!_sessionActive) return;
    _addAssistantMessage(
      '${VoiceCopy.timeoutWarningMain}\n${VoiceCopy.timeoutWarningSub}',
      type: ChatMessageType.system,
    );
  }

  @override
  void onSessionTimeout() async {
    if (!_sessionActive) return;
    _showSessionSummary();
    _addAssistantMessage('长时间无操作，已自动退出', type: ChatMessageType.system);
    await _speakSessionSummary();
    endSession();
  }

  @override
  void onSuggestPushToTalk() {
    if (!_sessionActive) return;
    _addAssistantMessage(
      '检测到多次环境噪音误触，建议切换到「手动模式」',
      type: ChatMessageType.system,
    );
  }

  @override
  void onError(String message) {
    if (!_sessionActive) return;
    if (_modeSwitchInProgress && message.contains('asr_send_error')) {
      if (kDebugMode) {
        debugPrint(
          '[VoiceSession] Suppressing onError(asr_send_error) during mode switch',
        );
      }
      return;
    }
    _cancelRecognizingTimeout();
    state = state.copyWith(
      isRecognizing: false,
      errorMessage: message,
      voiceState: VoiceState.listening,
      isProcessing: false,
    );
    HapticFeedback.vibrate();
    final isNoVoice = message.contains('未检测到语音');
    _addAssistantMessage(
      isNoVoice ? VoiceCopy.feedbackNoBill : '出了点问题：$message',
      type: isNoVoice ? ChatMessageType.normal : ChatMessageType.error,
    );
  }

  // ======================== Session Summary ========================

  void _showSessionSummary() {
    final text = _saveHelper?.buildSummaryText();
    if (text != null) {
      _addAssistantMessage(text, type: ChatMessageType.success);
    }
  }

  /// TTS session summary on exit.
  Future<void> _speakSessionSummary() async {
    final helper = _saveHelper;
    if (helper == null || !helper.hasTransactions) return;
    try {
      if (helper.totalAmount > 0) {
        await _orchestrator?.speakAndResumeTimer(
          TtsTemplates.sessionEnd(
            count: helper.count,
            total: helper.totalAmount,
          ),
        );
      }
    } catch (e) {
      dev.log('TTS summary speak failed: $e', name: 'VoiceSession', level: 900);
    }
  }

  /// Async budget check after expense save (non-blocking).
  void _checkBudgetAsyncFromEntity(TransactionEntity entity) {
    if (entity.type != TransactionType.expense) return;
    if (entity.categoryId == null) return;
    try {
      final budgetSvc = ref.read(budgetServiceProvider);
      final yearMonth = BudgetService.currentYearMonth();
      budgetSvc.checkAfterSave(
        categoryId: entity.categoryId!,
        yearMonth: yearMonth,
      );
    } catch (e) {
      dev.log('Budget check failed: $e', name: 'VoiceSession', level: 900);
    }
  }

  // ======================== Internal helpers ========================

  void _addAssistantMessage(
    String text, {
    ChatMessageType type = ChatMessageType.normal,
  }) {
    final msg = ChatMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      type: type,
    );
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  void _addUserMessage(String text) {
    final msg = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, msg]);
  }
}

final voiceSessionProvider =
    NotifierProvider<VoiceSessionNotifier, VoiceSessionState>(
      VoiceSessionNotifier.new,
    );
