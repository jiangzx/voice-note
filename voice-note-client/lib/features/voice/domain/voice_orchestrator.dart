import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/error_copy.dart';
import '../../../core/audio/native_audio_gateway.dart';
import '../../../core/audio/native_audio_models.dart';
import '../../../core/network/dto/transaction_correction_response.dart'
    as dto;
import '../../../core/tts/tts_templates.dart';
import '../data/asr_repository.dart';
import '../data/llm_repository.dart';
import '../presentation/widgets/mode_switcher.dart';
import 'asr_connection_manager.dart';
import 'draft_batch.dart';
import 'nlp_orchestrator.dart';
import 'parse_result.dart';
import 'voice_correction_handler.dart';
import 'voice_state.dart';

/// Callback interface for VoiceOrchestrator state changes.
abstract class VoiceOrchestratorDelegate {
  void onSpeechDetected();
  void onInterimText(String text);
  void onFinalText(String text, DraftBatch draftBatch);
  void onDraftBatchUpdated(DraftBatch draftBatch);
  /// Returns true if save succeeded (so orchestrator may speak success); false if save failed or was skipped.
  Future<bool> onBatchSaved(List<DraftTransaction> confirmedItems);
  void onConfirmTransaction();
  void onCancelTransaction();
  void onExitSession();
  void onContinueRecording();
  void onError(String message);

  /// Called when session times out due to prolonged inactivity.
  void onSessionTimeout();

  /// Called 30s before timeout to warn user.
  void onTimeoutWarning();

  /// Called when VAD misfires repeatedly — suggest switching to PTT mode.
  void onSuggestPushToTalk();

  /// Called when voice state changes (e.g., recognizing -> listening).
  void onStateChanged(VoiceState newState);

  /// Called when ASR final text is about to be processed (auto mode only); show recognition loading.
  void onRecognizingStarted();
}

/// Orchestrates the full voice pipeline: AudioCapture → VAD → ASR → NLP.
///
/// Manages three input modes:
/// - **auto**: VAD-controlled ASR connection lifecycle (zero cloud cost in silence)
/// - **pushToTalk**: Manual start/stop via button press
/// - **keyboard**: No audio services, text-only input
class VoiceOrchestrator {
  final AsrRepository _asrRepository;
  final NlpOrchestrator _nlpOrchestrator;
  final VoiceCorrectionHandler _correctionHandler;
  final VoiceOrchestratorDelegate _delegate;
  final AsrConnectionManager _asrConnection;
  final NativeAudioGateway? _nativeAudioGateway;
  final String? _nativeAudioSessionId;
  final double Function()? _getSpeechRate;

  // Owned services — created/destroyed per session
  StreamSubscription<NativeAudioEvent>? _nativeAudioSub;
  final Map<String, Completer<void>> _nativeTtsCompletions = <String, Completer<void>>{};

  VoiceState _currentState = VoiceState.idle;
  bool _disposed = false;

  // Current input mode tracking
  VoiceInputMode? _currentInputMode;

  /// Server VAD silence_duration_ms for auto mode (200–6000). Used in session.update.
  static const int _vadSilenceMsMin = 200;
  static const int _vadSilenceMsMax = 6000;
  int _vadSilenceDurationMs = 1000;

  // Track if pushEnd is pending (waiting for asrFinalText)
  bool _isPushEndPending = false;
  Completer<void>? _pushEndCompleter;

  /// Accumulates asrFinalText segments while user is still holding (pushToTalk).
  /// Merged with the final segment on release so multi-phrase input is not lost.
  final List<String> _pushToTalkFinalTextBuffer = [];

  /// After pushCancel we commit to flush server buffer; discard the next asrFinalText (that commit’s result).
  int _discardAsrFinalTextCount = 0;

  DraftBatch? _draftBatch;

  // TTS VAD suppression flag
  bool _isTtsSpeaking = false;

  // Inactivity timeout
  static const Duration inactivityTimeout = Duration(minutes: 3);
  static const Duration timeoutWarningBefore = Duration(seconds: 30);
  Timer? _inactivityTimer;
  Timer? _timeoutWarningTimer;

  // Push-to-talk timing constants
  static const Duration _pushStartDelay = Duration(milliseconds: 150);
  static const Duration _pushEndCommitDelay = Duration(milliseconds: 300);
  static const Duration _pushEndTimeout = Duration(seconds: 1);
  static const Duration pushToTalkMaxHoldDuration = Duration(seconds: 60);
  Timer? _pushToTalkAutoReleaseTimer;

  // Correction in-flight guard — blocks confirm/cancel during LLM request
  bool _isCorrecting = false;

  // VAD misfire tracking (保留用于兼容性，但不再使用)
  // Note: VAD功能已移至原生层，此字段保留用于未来可能的用途
  static const int maxConsecutiveMisfires = 3;
  // ignore: unused_field
  int _consecutiveMisfires = 0;

  // Native audio telemetry
  int _falseTriggerCount = 0;
  int _focusLossCount = 0;
  DateTime? _bargeInTriggeredAt;
  DateTime? _resumeStartAt;
  bool _bargeInPending = false;
  DateTime? _ttsEndedAt;
  static const Duration _ttsEchoDiscardWindow = Duration(milliseconds: 1200);

  /// Set when TTS was stopped by pushStart (user pressed PTT). Skip "recent TTS ended" discard for this hold.
  bool _ttsStoppedByUserAction = false;

  /// When set, TTS was stopped by program (mode switch / confirm). Skip "recent TTS ended" discard for this window.
  DateTime? _ttsStoppedByProgramAt;

  VoiceOrchestrator({
    required AsrRepository asrRepository,
    required NlpOrchestrator nlpOrchestrator,
    required VoiceCorrectionHandler correctionHandler,
    required VoiceOrchestratorDelegate delegate,
    NativeAudioGateway? nativeAudioGateway,
    String? nativeAudioSessionId,
    AsrConnectionManager? asrConnectionManager,
    double Function()? getSpeechRate,
  }) : _nlpOrchestrator = nlpOrchestrator,
       _asrRepository = asrRepository,
       _correctionHandler = correctionHandler,
       _delegate = delegate,
       _nativeAudioGateway = nativeAudioGateway,
       _nativeAudioSessionId = nativeAudioSessionId,
       _getSpeechRate = getSpeechRate,
       _asrConnection = asrConnectionManager ??
           AsrConnectionManager(asrRepository: asrRepository) {
    _asrConnection.onInterimText =
        (String text) => _delegate.onInterimText(text);
    _asrConnection.onFinalText = (String text) => _onAsrFinalText(text);
    _asrConnection.onError = (String msg) => _delegate.onError(msg);
    _asrConnection.onReconnectFailed = () {
      _delegate.onError(ErrorCopy.asrReconnectFailed);
      _currentState = VoiceState.listening;
    };
    _asrConnection.onReconnecting = (int attempt, int max) {
      _delegate.onError('连接中断，正在重连 ($attempt/$max)...');
    };
    _asrConnection.shouldReconnect =
        () => !_disposed && _currentState == VoiceState.recognizing;
  }

  VoiceState get currentState => _currentState;

  // ======================== Public API ========================

  /// Start listening for voice input in the given [mode].
  /// Keyboard mode initializes native session for TTS only (no ASR/capture).
  /// [vadSilenceDurationMs] is used for auto mode server VAD (default 1000).
  Future<void> startListening(
    VoiceInputMode mode, {
    int? vadSilenceDurationMs,
  }) async {
    if (kDebugMode) debugPrint('[VoiceInit] startListening(mode=$mode)');
    _currentInputMode = mode;
    if (vadSilenceDurationMs != null) {
      _vadSilenceDurationMs =
          vadSilenceDurationMs.clamp(_vadSilenceMsMin, _vadSilenceMsMax);
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      throw StateError('Native audio runtime is only supported on Android and iOS');
    }
    if (_nativeAudioGateway == null || _nativeAudioSessionId == null) {
      throw StateError('Native audio gateway not configured');
    }

    try {
      await _initNativeAudioRuntime(mode);
      if (mode != VoiceInputMode.keyboard) {
        await _startNativeAsrStream();
      } else if (kDebugMode) {
        debugPrint('[VoiceInit] Keyboard mode — TTS-only init, ASR skipped');
      }
      _currentState = VoiceState.listening;
      _startInactivityTimer();
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceInit] FAILED: $e');
      final errorStr = e.toString();
      String userMessage;
      String? logCode;
      if (errorStr.contains('RECORD_AUDIO permission not granted') ||
          errorStr.contains('permission may be denied')) {
        userMessage = ErrorCopy.recordNoPermission;
      } else if (errorStr.contains('audio_record_start_failed') ||
          errorStr.contains('AudioRecord initialization failed')) {
        if (errorStr.contains('state=0') ||
            errorStr.contains('STATE_UNINITIALIZED') ||
            errorStr.contains('permission may be denied')) {
          userMessage = ErrorCopy.recordBusy;
        } else {
          userMessage = ErrorCopy.recordStartFailed;
        }
      } else if (e is AsrTokenException) {
        if (errorStr.contains('TimeoutException') ||
            errorStr.contains('Request timed out')) {
          logCode = 'E-ASR-001';
          userMessage = ErrorCopy.asrTimeout;
        } else if (errorStr.contains('NetworkUnavailableException') ||
            errorStr.contains('Network unavailable')) {
          logCode = 'E-ASR-002';
          userMessage = ErrorCopy.asrNetwork;
        } else if (errorStr.contains('RateLimitException') ||
            errorStr.contains('Rate limit')) {
          logCode = 'E-ASR-003';
          userMessage = ErrorCopy.asrRateLimit;
        } else if (errorStr.contains('Invalid token response')) {
          logCode = 'E-ASR-004';
          userMessage = ErrorCopy.asrUnavailable;
        } else {
          logCode = 'E-ASR-005';
          userMessage = ErrorCopy.asrStartFailed;
        }
      } else {
        userMessage = ErrorCopy.asrStartFailed;
      }
      if (kDebugMode && logCode != null) debugPrint('[VoiceInit] $logCode');
      _delegate.onError(userMessage);
    }
  }

  Future<void> _startNativeAsrStream() async {
    final native = _nativeAudioGateway;
    final nativeSessionId = _nativeAudioSessionId;
    if (native == null || nativeSessionId == null) {
      throw StateError('native_audio_not_configured');
    }
    if (kDebugMode) {
      debugPrint(
          '[ASRFlow] _startNativeAsrStream mode=${_currentInputMode?.name ?? "null"}',
      );
    }
    final token = await _asrRepository.getToken();
    final result = await native.startAsrStream(
      sessionId: nativeSessionId,
      token: token.token,
      wsUrl: token.wsUrl,
      model: token.model,
      vadSilenceDurationMs: _vadSilenceDurationMs,
    );
    final ok = result['ok'] as bool? ?? false;
    if (!ok) {
      final error = result['error'] as String? ?? 'unknown_error';
      final message = result['message'] as String?;
      final errorMsg = message != null 
          ? 'native_asr_stream_start_failed: $error ($message)'
          : 'native_asr_stream_start_failed: $error';
      throw StateError(errorMsg);
    }
  }

  /// Start push-to-talk: connect ASR immediately and stream audio.
  Future<void> pushStart() async {
    // 强制使用原生音频路径
    _cancelInactivityTimer();
    _currentState = VoiceState.recognizing;
    _delegate.onSpeechDetected();

    // 在 pushToTalk 模式下，启动 captureRuntime 并 unmute ASR
    if (_currentInputMode == VoiceInputMode.pushToTalk) {
      if (_isTtsSpeaking) {
        await stopTtsIfPlaying();
        _ttsStoppedByUserAction = true;
        if (kDebugMode) {
          debugPrint('[VoiceMode] pushStart: Stopped TTS for user speech');
        }
      }
      _pushToTalkFinalTextBuffer.clear();
      final native = _nativeAudioGateway;
      final nativeSessionId = _nativeAudioSessionId;
      if (native != null && nativeSessionId != null) {
        try {
          if (kDebugMode) {
            debugPrint('[VoiceMode] pushStart: Starting capture');
          }
          // 先启动 captureRuntime（如果未运行）
          await native.startCapture(sessionId: nativeSessionId);
          // 等待足够的时间确保 captureRuntime 完全启动和 ASR 连接建立
          // 增加延迟以提高短按的可靠性
          await Future.delayed(_pushStartDelay, () {});
          // 然后 unmute ASR
          await native.setAsrMuted(
            sessionId: nativeSessionId,
            muted: false,
            reason: 'push_start',
          );
          if (kDebugMode) {
            debugPrint('[VoiceMode] Started capture and unmuted ASR for pushToTalk mode');
          }
          _pushToTalkAutoReleaseTimer?.cancel();
          _pushToTalkAutoReleaseTimer = Timer(pushToTalkMaxHoldDuration, () {
            _pushToTalkAutoReleaseTimer = null;
            pushEnd();
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[VoiceMode] Failed to start capture/unmute ASR: $e');
          }
        }
      }
    }
  }

  /// End push-to-talk: commit audio and process result.
  Future<void> pushEnd() async {
    _pushToTalkAutoReleaseTimer?.cancel();
    _pushToTalkAutoReleaseTimer = null;
    // 强制使用原生音频路径
    final native = _nativeAudioGateway;
    final nativeSessionId = _nativeAudioSessionId;
    if (native != null && nativeSessionId != null) {
      // 在 pushToTalk 模式下，按正确顺序停止
      if (_currentInputMode == VoiceInputMode.pushToTalk) {
        // 设置标志，表示正在等待 asrFinalText
        _isPushEndPending = true;
        _pushEndCompleter = Completer<void>();

        try {
          if (kDebugMode) {
            debugPrint('[VoiceMode] pushEnd: Starting, waiting for asrFinalText');
          }

          // 步骤 1: 先 mute ASR（停止发送新的音频帧）
          // 但保持 captureRuntime 运行，让已缓冲的帧继续发送
          await native.setAsrMuted(
            sessionId: nativeSessionId,
            muted: true,
            reason: 'push_end',
          );

          // 步骤 2: 等待一小段时间，让已发送的音频帧被 ASR 服务器处理
          // 这确保完整的音频流被处理，避免截断
          await Future.delayed(_pushEndCommitDelay, () {});

          // 步骤 3: 然后 commit（告诉服务器处理已发送的音频）
          native.commitAsr(nativeSessionId);

          if (kDebugMode) {
            debugPrint('[VoiceMode] pushEnd: Committed ASR, waiting for final text');
          }

          // 步骤 4: 停止 captureRuntime（释放麦克风资源，听筒不亮）
          native.stopCapture(sessionId: nativeSessionId);

          // 步骤 5: 等待 asrFinalText 事件（最多等待 1 秒）
          try {
            await _pushEndCompleter!.future.timeout(
              _pushEndTimeout,
              onTimeout: () {
                if (kDebugMode) {
                  debugPrint('[VoiceMode] pushEnd: Timeout waiting for asrFinalText');
                }
                // 超时多为 ASR/网络不可用，提示检查网络或改用键盘，避免误用「没听清」
                if (_isPushEndPending) {
                  _delegate.onError(ErrorCopy.asrNoResult);
                }
              },
            );
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[VoiceMode] pushEnd: Error waiting for asrFinalText: $e');
            }
            if (_isPushEndPending) {
              _delegate.onError(ErrorCopy.asrNoResult);
            }
          }

          if (kDebugMode) {
            debugPrint('[VoiceMode] Stopped capture and muted ASR for pushToTalk mode');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[VoiceMode] Failed to stop capture/mute ASR: $e');
          }
          // Ensure error is reported if not already handled
          if (_isPushEndPending) {
            _delegate.onError(ErrorCopy.recordStartFailed);
          }
        } finally {
          if (_pushToTalkFinalTextBuffer.isNotEmpty) {
            _onAsrFinalText(_pushToTalkFinalTextBuffer.join(''));
            _pushToTalkFinalTextBuffer.clear();
          }
          _isPushEndPending = false;
          _pushEndCompleter = null;
          _ttsStoppedByUserAction = false;
        }
      } else {
        // 非 pushToTalk 模式，直接 commit
        native.commitAsr(nativeSessionId);
      }
    }
    _currentState = VoiceState.listening;
    _delegate.onStateChanged(VoiceState.listening);
    _startInactivityTimer();
  }

  /// Cancel push-to-talk: commit to flush server buffer (so next recording is clean), then discard that result.
  /// Used when user slides up to cancel (release in cancel zone).
  Future<void> pushCancel() async {
    _pushToTalkAutoReleaseTimer?.cancel();
    _pushToTalkAutoReleaseTimer = null;
    final native = _nativeAudioGateway;
    final nativeSessionId = _nativeAudioSessionId;
    if (native != null &&
        nativeSessionId != null &&
        _currentInputMode == VoiceInputMode.pushToTalk) {
      try {
        await native.setAsrMuted(
          sessionId: nativeSessionId,
          muted: true,
          reason: 'push_cancel',
        );
        await Future.delayed(_pushEndCommitDelay, () {});
        native.commitAsr(nativeSessionId);
        native.stopCapture(sessionId: nativeSessionId);
        _pushToTalkFinalTextBuffer.clear();
        _discardAsrFinalTextCount = 1;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[VoiceMode] pushCancel: $e');
        }
      }
      _ttsStoppedByUserAction = false;
    }
    _currentState = VoiceState.listening;
    _delegate.onStateChanged(VoiceState.listening);
    _startInactivityTimer();
  }

  /// Process text input directly (keyboard mode).
  Future<void> processTextInput(String text) async {
    if (text.trim().isEmpty) return;
    _cancelInactivityTimer();

    if (_currentState == VoiceState.confirming) {
      await _handleConfirmingSpeech(text);
      return;
    }

    _currentState = VoiceState.recognizing;
    _delegate.onSpeechDetected();
    await _parseAndDeliver(text);
  }

  /// Switch input mode at runtime (e.g., auto <-> pushToTalk).
  /// [previousMode] used to revert native and _currentInputMode when switching to auto fails.
  /// [vadSilenceDurationMs] used when reconnecting ASR for auto mode.
  Future<void> switchInputMode(
    VoiceInputMode mode, {
    VoiceInputMode? previousMode,
    int? vadSilenceDurationMs,
  }) async {
    if (vadSilenceDurationMs != null) {
      _vadSilenceDurationMs =
          vadSilenceDurationMs.clamp(_vadSilenceMsMin, _vadSilenceMsMax);
    }
    // Clear any pending draft batch when switching modes to prevent
    // misinterpreting new input as correction
    if (_currentState == VoiceState.confirming && _draftBatch != null) {
      final batch = _draftBatch!;
      // Save any confirmed items before clearing
      if (batch.confirmedItems.isNotEmpty) {
        await _delegate.onBatchSaved(batch.confirmedItems);
      }
      // Clear the batch and reset to listening state
      _draftBatch = null;
      _currentState = VoiceState.listening;
      _startInactivityTimer();
      _delegate.onContinueRecording();
      if (kDebugMode) {
        debugPrint('[VoiceMode] Cleared draft batch on mode switch');
      }
    }

    await stopTtsIfPlaying();

    if (mode == VoiceInputMode.keyboard) {
      _currentInputMode = mode;
      if (kDebugMode) debugPrint('[VoiceMode] Switching to keyboard mode');
      return;
    }

    final native = _nativeAudioGateway;
    final nativeSessionId = _nativeAudioSessionId;
    if (native == null || nativeSessionId == null) {
      if (kDebugMode) debugPrint('[VoiceMode] Native audio not configured, skipping mode switch');
      return;
    }

    try {
      await native.switchInputMode(
        sessionId: nativeSessionId,
        mode: mode.name,
      );
      // Reconnect ASR with server_vad when switching to auto so server does turn detection.
      if (mode == VoiceInputMode.auto) {
        if (kDebugMode) {
          debugPrint('[VoiceMode] Reconnecting ASR for auto (useServerVad=true)');
        }
        await native.stopAsrStream(nativeSessionId);
        await _startNativeAsrStream();
      }
      // Reconnect ASR with client commit when switching from auto to pushToTalk so manual commit gets asrFinalText.
      if (mode == VoiceInputMode.pushToTalk &&
          previousMode == VoiceInputMode.auto) {
        if (kDebugMode) {
          debugPrint('[VoiceMode] Reconnecting ASR for pushToTalk from auto (useServerVad=false)');
        }
        await native.stopAsrStream(nativeSessionId);
        await _startNativeAsrStream();
      }
      _currentInputMode = mode;
      if (kDebugMode) debugPrint('[VoiceMode] Switched to ${mode.name}');
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceMode] Failed to switch mode: $e');
      final shouldRevert = (mode == VoiceInputMode.auto &&
              previousMode != null &&
              previousMode != VoiceInputMode.keyboard) ||
          (mode == VoiceInputMode.pushToTalk &&
              previousMode == VoiceInputMode.auto);
      if (shouldRevert && previousMode != null) {
        try {
          await native.switchInputMode(
            sessionId: nativeSessionId,
            mode: previousMode.name,
          );
          _currentInputMode = previousMode;
          if (kDebugMode) {
            debugPrint(
                '[VoiceMode] Reverted to ${previousMode.name} after mode switch failed');
          }
        } catch (revertErr) {
          if (kDebugMode) debugPrint('[VoiceMode] Revert failed: $revertErr');
        }
      }
      _delegate.onError(ErrorCopy.asrTimeout);
    }
  }

  /// Clear draft batch and reset to listening state.
  /// Called when user confirms transaction via UI button to ensure
  /// subsequent input is treated as new input, not correction.
  void clearDraftBatch() {
    _draftBatch = null;
    if (_currentState == VoiceState.confirming) {
      _currentState = VoiceState.listening;
      _startInactivityTimer();
    }
  }

  /// Stop any playing TTS and clear local TTS state. Call on mode switch, confirm, or pushStart (manual) to interrupt playback.
  Future<void> stopTtsIfPlaying() async {
    if (!_isTtsSpeaking) return;
    final native = _nativeAudioGateway;
    final nativeSessionId = _nativeAudioSessionId;
    if (native == null || nativeSessionId == null) return;
    final requestIds = _nativeTtsCompletions.keys.toList();
    if (requestIds.isEmpty) {
      _isTtsSpeaking = false;
      return;
    }
    for (final requestId in requestIds) {
      try {
        await native.stopTts(
          sessionId: nativeSessionId,
          requestId: requestId,
          reason: 'user_action',
        );
      } catch (_) {
        // Best-effort; continue stopping others.
      }
    }
    for (final completer in _nativeTtsCompletions.values) {
      if (!completer.isCompleted) completer.complete();
    }
    _nativeTtsCompletions.clear();
    _isTtsSpeaking = false;
    _ttsStoppedByProgramAt = clock.now();
    if (kDebugMode) {
      debugPrint('[TTSFlow] stopTtsIfPlaying: stopped ${requestIds.length} TTS request(s)');
    }
  }

  /// Stop ASR and release mic; keeps native session (and TTS) alive for keyboard mode.
  Future<void> stopListening() async {
    _draftBatch = null;
    _asrConnection.resetReconnectAttempts();
    _consecutiveMisfires = 0;
    _isTtsSpeaking = false;
    _bargeInTriggeredAt = null;
    _resumeStartAt = null;
    _bargeInPending = false;
    _ttsStoppedByUserAction = false;
    _ttsStoppedByProgramAt = null;
    _currentInputMode = null;
    _cancelInactivityTimer();
    _pushToTalkAutoReleaseTimer?.cancel();
    _pushToTalkAutoReleaseTimer = null;
    _asrConnection.cancelSubscriptions();
    await _nativeAudioSub?.cancel();
    _nativeAudioSub = null;
    final nativeSessionId = _nativeAudioSessionId;
    final native = _nativeAudioGateway;
    if (native != null && nativeSessionId != null) {
      try {
        await native.stopAsrStream(nativeSessionId);
      } catch (_) {
        // Keep cleanup resilient if native runtime isn't ready yet.
      }
    }
    _currentState = VoiceState.idle;
  }

  /// Release native session (TTS, capture, ASR). Call when leaving voice screen.
  Future<void> _disposeNativeSession() async {
    final nativeSessionId = _nativeAudioSessionId;
    final native = _nativeAudioGateway;
    if (native != null && nativeSessionId != null) {
      try {
        await native.disposeSession(nativeSessionId);
      } catch (_) {}
    }
  }

  /// Speak text with VAD suppression — ignore VAD events during playback.
  Future<void> _speakWithSuppression(String text) async {
    final native = _nativeAudioGateway;
    final nativeSessionId = _nativeAudioSessionId;
    if (native == null || nativeSessionId == null || text.isEmpty) {
      return;
    }

    final requestId = 'tts_${DateTime.now().microsecondsSinceEpoch}';
    final completer = Completer<void>();
    _nativeTtsCompletions[requestId] = completer;
    _isTtsSpeaking = true;
    if (kDebugMode) {
      debugPrint('[TTSFlow] Native playTts request=$requestId text="$text"');
    }
    final effectiveRate = _getSpeechRate?.call() ?? 1.0;
    try {
      final result = await native.playTts(
        sessionId: nativeSessionId,
        requestId: requestId,
        text: text,
        speechRate: effectiveRate,
      );
      final ok = result['ok'] as bool? ?? false;
      if (!ok) {
        dev.log(
          'Native TTS play failed: result=$result',
          name: 'VoiceOrchestrator',
          level: 900,
        );
        throw StateError('native_tts_play_failed');
      }
      // Native TTS engine may need extra warmup time on first launch.
      await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[TTSFlow] Native TTS timeout request=$requestId');
      }
      try {
        await native.stopTts(
          sessionId: nativeSessionId,
          requestId: requestId,
          reason: 'native_timeout',
        );
      } catch (_) {
        // Keep timeout rollback best-effort.
      }
      // Avoid surfacing startup warmup delays as user-facing errors.
      dev.log(
        'Native TTS timeout request=$requestId',
        name: 'VoiceOrchestrator',
        level: 900,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TTSFlow] Native TTS failed: $e');
      }
      _delegate.onError(ErrorCopy.retryLater);
    } finally {
      _nativeTtsCompletions.remove(requestId);
      _isTtsSpeaking = false;
    }
  }

  Future<void> _initNativeAudioRuntime(VoiceInputMode mode) async {
    final native = _nativeAudioGateway;
    final nativeSessionId = _nativeAudioSessionId;
    if (native == null || nativeSessionId == null) {
      throw StateError('native_audio_not_configured');
    }

    _nativeAudioSub ??= native.events.listen(_onNativeAudioEvent);
    final enableCapture = mode != VoiceInputMode.keyboard;
    final initResult = await native.initializeSession(
      sessionId: nativeSessionId,
      mode: mode.name,
      platformConfig: <String, Object?>{
        'enableNativeCapture': enableCapture,
      },
    );
    final ok = initResult['ok'] as bool? ?? false;
    if (!ok) {
      final error = initResult['error'] as String? ?? 'unknown_error';
      final message = initResult['message'] as String? ?? error;
      if (kDebugMode) {
        debugPrint(
          '[VoiceInit] initializeSession failed: error=$error message=$message',
        );
      }
      throw StateError('native_audio_init_failed: $error - $message');
    }
    if (kDebugMode) {
      debugPrint('[VoiceInit] initializeSession ok');
    }

    await native.switchInputMode(
      sessionId: nativeSessionId,
      mode: mode.name,
    );

    // Keyboard mode uses TTS only; skip capture-active check.
    if (mode == VoiceInputMode.keyboard) {
      if (kDebugMode) debugPrint('[VoiceInit] Keyboard mode — skip capture check');
      return;
    }
    final status = await native.getDuplexStatus(nativeSessionId);
    final captureActive = status['captureActive'] as bool? ?? false;
    if (mode != VoiceInputMode.pushToTalk && !captureActive) {
      if (kDebugMode) {
        debugPrint('[VoiceInit] getDuplexStatus: captureActive=false');
      }
      throw StateError('capture_not_active_after_init');
    }
    if (kDebugMode) {
      debugPrint('[VoiceInit] Capture verified active: $captureActive (mode=$mode)');
    }
  }

  void _onNativeAudioEvent(NativeAudioEvent event) {
    if (_nativeAudioSessionId == null || event.sessionId != _nativeAudioSessionId) {
      return;
    }
    if (event.event == 'ttsStarted') {
      _isTtsSpeaking = true;
      return;
    }

    if (event.event == 'ttsInitDiagnostics') {
      final d = event.data;
      final engineList = d['engineList'];
      final engineListStr = engineList is List
          ? (engineList.map((e) => e?.toString() ?? '')).join(',')
          : engineList?.toString() ?? '';
      if (kDebugMode) {
        debugPrint('[TTSDiag] engineList=$engineListStr');
        debugPrint('[TTSDiag] defaultEngine=${d['defaultEngine']}');
        debugPrint('[TTSDiag] engineUsed=${d['engineUsed']}');
        debugPrint('[TTSDiag] initStatus=${d['initStatus']} (${d['initStatusName']}) initErrorCode=${d['initErrorCode']}');
        debugPrint('[TTSDiag] contextValid=${d['contextValid']} isActivityContext=${d['isActivityContext']} activityValid=${d['activityValid']} onMainThread=${d['onMainThread']}');
        debugPrint('[TTSDiag] asrActive=${d['asrActive']} audioRecordActive=${d['audioRecordActive']}');
      }
      dev.log(
        'native_tts_init_diagnostics engineList=$engineListStr defaultEngine=${d['defaultEngine']} engineUsed=${d['engineUsed']} initStatus=${d['initStatus']} initSuccess=${d['initSuccess']}',
        name: 'VoiceTelemetry',
      );
      final initSuccess = d['initSuccess'] as bool? ?? false;
      _emitTelemetryMetric(
        'ttsInitSuccess',
        initSuccess ? 1.0 : 0.0,
        dimensions: <String, Object?>{
          'engineList': engineListStr.isNotEmpty ? engineListStr : null,
          'defaultEngine': d['defaultEngine']?.toString(),
          'engineUsed': d['engineUsed']?.toString(),
          'initStatus': d['initStatus'],
          'initStatusName': d['initStatusName']?.toString(),
          'initErrorCode': d['initErrorCode'],
          'contextValid': d['contextValid'],
          'isActivityContext': d['isActivityContext'],
          'activityValid': d['activityValid'],
          'onMainThread': d['onMainThread'],
          'asrActive': d['asrActive'],
          'audioRecordActive': d['audioRecordActive'],
        },
      );
      return;
    }

    if (event.event == 'asrInterimText') {
      // 键盘模式：忽略所有 ASR 事件
      if (_currentInputMode == VoiceInputMode.keyboard) {
        if (kDebugMode) {
          debugPrint('[ASRFlow] Ignore asrInterimText (keyboard mode)');
        }
        return;
      }
      // 手动模式：只有在 recognizing 状态下才处理
      if (_currentInputMode == VoiceInputMode.pushToTalk &&
          _currentState != VoiceState.recognizing) {
        if (kDebugMode) {
          debugPrint('[ASRFlow] Ignore asrInterimText (pushToTalk mode, not recognizing)');
        }
        return;
      }
      // TTS 播放中或刚结束的回声窗口内不派发 interim，避免 TTS 被识别后误触发
      if (_isTtsSpeaking) return;
      if (_ttsEndedAt != null &&
          clock.now().difference(_ttsEndedAt!) < _ttsEchoDiscardWindow) {
        // Program stopped TTS (mode switch/confirm): allow interim in this window.
        if (_ttsStoppedByProgramAt == null ||
            clock.now().difference(_ttsStoppedByProgramAt!) >= _ttsEchoDiscardWindow) {
          return;
        }
      }
      // 自动模式：正常处理
      final text = event.data['text'] as String?;
      if (text != null && text.isNotEmpty) {
        _delegate.onInterimText(text);
      }
      return;
    }

    if (event.event == 'asrFinalText') {
      final textFromEvent = event.data['text'] as String?;
      if (kDebugMode) {
        debugPrint(
          '[ASRFlow] Received asrFinalText length=${textFromEvent?.length ?? 0}',
        );
      }
      // 键盘模式：忽略所有 ASR 事件
      if (_currentInputMode == VoiceInputMode.keyboard) {
        if (kDebugMode) {
          debugPrint('[ASRFlow] Ignore asrFinalText (keyboard mode)');
        }
        return;
      }
      // 上滑取消后 commit 产生的 asrFinalText 丢弃接下来若干条（同一次 commit 可能 1～2 条）
      if (_currentInputMode == VoiceInputMode.pushToTalk &&
          _discardAsrFinalTextCount > 0) {
        if (kDebugMode) {
          debugPrint(
            '[ASRFlow] Discard asrFinalText (from pushCancel commit, remaining=$_discardAsrFinalTextCount)',
          );
        }
        _discardAsrFinalTextCount--;
        return;
      }
      // 手动模式：仍按住时只累积到 buffer，松开后再与最后一段合并处理
      if (_currentInputMode == VoiceInputMode.pushToTalk &&
          !_isPushEndPending) {
        if (textFromEvent != null && textFromEvent.isNotEmpty) {
          _pushToTalkFinalTextBuffer.add(textFromEvent);
          if (kDebugMode) {
            debugPrint(
              '[ASRFlow] PushToTalk accumulated segment (still holding): "${textFromEvent.replaceAll(RegExp(r'\s+'), ' ').trim()}"',
            );
          }
        }
        return;
      }

      // 如果 pushEnd 正在等待，完成等待
      if (_isPushEndPending && _pushEndCompleter != null) {
        if (kDebugMode) {
          debugPrint('[ASRFlow] Received asrFinalText during pushEnd, completing wait');
        }
        _pushEndCompleter!.complete();
      }

      final text = textFromEvent;
      // Check for empty text: if pushToTalk and pushEnd is pending, either process buffer or empty recording
      if (text == null || text.isEmpty) {
        if (_currentInputMode == VoiceInputMode.pushToTalk &&
            _isPushEndPending &&
            _pushToTalkFinalTextBuffer.isNotEmpty) {
          final combined = _pushToTalkFinalTextBuffer.join('');
          _pushToTalkFinalTextBuffer.clear();
          _onAsrFinalText(combined);
          return;
        }
        if (_currentInputMode == VoiceInputMode.pushToTalk && _isPushEndPending) {
          if (kDebugMode) {
            debugPrint('[ASRFlow] Empty text received during pushEnd (empty recording)');
          }
          return;
        }
        return;
      }
      if (_isTtsSpeaking) {
        if (kDebugMode) {
          debugPrint('[ASRFlow] Discard asrFinalText (TTS playing): "$text"');
        }
        dev.log(
          'discard asrFinalText (TTS playing)',
          name: 'VoiceOrchestrator',
        );
        return;
      }
      if (_ttsEndedAt != null &&
          clock.now().difference(_ttsEndedAt!) < _ttsEchoDiscardWindow) {
        // User stopped TTS by pressing PTT: this asrFinalText is their speech, do not discard.
        if (_ttsStoppedByUserAction) {
          if (kDebugMode) {
            debugPrint('[ASRFlow] Accept asrFinalText (TTS stopped by pushStart): "$text"');
          }
        } else if (_bargeInTriggeredAt != null &&
            clock.now().difference(_bargeInTriggeredAt!) < _ttsEchoDiscardWindow) {
          // Barge-in just happened: this is the user's interrupting phrase, do not discard.
          if (kDebugMode) {
            debugPrint('[ASRFlow] Accept asrFinalText (after barge-in): "$text"');
          }
        } else if (_ttsStoppedByProgramAt != null &&
            clock.now().difference(_ttsStoppedByProgramAt!) < _ttsEchoDiscardWindow) {
          // Program stopped TTS (mode switch/confirm): accept user speech in this window.
          if (kDebugMode) {
            debugPrint('[ASRFlow] Accept asrFinalText (TTS stopped by program): "$text"');
          }
        } else {
          if (kDebugMode) {
            debugPrint(
              '[ASRFlow] Discard asrFinalText (recent TTS ended): "$text"',
            );
          }
          dev.log(
            'discard asrFinalText (recent TTS ended)',
            name: 'VoiceOrchestrator',
          );
          return;
        }
      }
      if (_currentInputMode == VoiceInputMode.auto) {
        // Confirming: user said 确认/取消 — handle in _onAsrFinalText without showing "正在识别" or starting timeout.
        if (_currentState != VoiceState.confirming) {
          _delegate.onRecognizingStarted();
        }
      }
      if (_currentInputMode == VoiceInputMode.pushToTalk &&
          _pushToTalkFinalTextBuffer.isNotEmpty) {
        final combined =
            _pushToTalkFinalTextBuffer.join('') + (text);
        _pushToTalkFinalTextBuffer.clear();
        _onAsrFinalText(combined);
      } else {
        _onAsrFinalText(text);
      }
      return;
    }

    if (event.event == 'ttsCompleted' || event.event == 'ttsStopped') {
      if (_bargeInPending && _bargeInTriggeredAt != null) {
        final ttsStopCostMs =
            clock.now().difference(_bargeInTriggeredAt!).inMilliseconds;
        _emitTelemetryMetric('ttsStopCostMs', ttsStopCostMs.toDouble());
        _resumeStartAt = clock.now();
      }
      _isTtsSpeaking = false;
      _ttsEndedAt = clock.now();
      _ttsStoppedByProgramAt = null;
      final requestId = event.requestId;
      if (requestId != null) {
        final completer = _nativeTtsCompletions.remove(requestId);
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      } else if (_nativeTtsCompletions.isNotEmpty) {
        final fallbackId = _nativeTtsCompletions.keys.first;
        final completer = _nativeTtsCompletions.remove(fallbackId);
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      }
      return;
    }

    if (event.event == 'ttsError') {
      _isTtsSpeaking = false;
      _ttsEndedAt = clock.now();
      _ttsStoppedByProgramAt = null;
      final requestId = event.requestId;
      if (requestId != null) {
        final completer = _nativeTtsCompletions.remove(requestId);
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      } else if (_nativeTtsCompletions.isNotEmpty) {
        final fallbackId = _nativeTtsCompletions.keys.first;
        final completer = _nativeTtsCompletions.remove(fallbackId);
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      }
      if (event.error != null &&
          event.error!.code != NativeAudioError.codeTtsUnavailable) {
        _delegate.onError(ErrorCopy.retryLater);
      }
      return;
    }

    if (event.event == 'asrMuteStateChanged') {
      final muted = event.data['asrMuted'] as bool?;
      if (muted == false && _resumeStartAt != null) {
        final resumeCostMs = clock.now().difference(_resumeStartAt!).inMilliseconds;
        _emitTelemetryMetric('resumeCostMs', resumeCostMs.toDouble());
        _resumeStartAt = null;
      }
      return;
    }

    if (event.event == 'bargeInTriggered') {
      // A barge-in trigger when TTS is not speaking is treated as false trigger.
      if (!_isTtsSpeaking) {
        _falseTriggerCount++;
        _emitTelemetryMetric(
          'falseTriggerCount',
          _falseTriggerCount.toDouble(),
        );
      }
      _bargeInPending = true;
      _bargeInTriggeredAt = clock.now();
      return;
    }

    if (event.event == 'bargeInCompleted') {
      if (_bargeInTriggeredAt != null) {
        final bargeInLatencyMs =
            clock.now().difference(_bargeInTriggeredAt!).inMilliseconds;
        _emitTelemetryMetric('bargeInLatencyMs', bargeInLatencyMs.toDouble());
      }
      _bargeInTriggeredAt = null;
      _bargeInPending = false;
      return;
    }

    if (event.event == 'audioFocusChanged') {
      if (event.focusState.startsWith('loss')) {
        _focusLossCount++;
        _emitTelemetryMetric('focusLossCount', _focusLossCount.toDouble());
      }
      return;
    }

    if (event.event == 'runtimeError' && event.error != null) {
      final errorMessage = event.error!.message;
      // Suppress empty recording errors for better UX
      if (errorMessage.contains('error committing input audio buffer') ||
          errorMessage.contains('maybe no invalid audio stream') ||
          errorMessage.contains('no audio')) {
        if (kDebugMode) {
          debugPrint('[VoiceMode] Suppressing empty recording error: $errorMessage');
        }
        return; // Suppress the error
      }
      if (errorMessage.startsWith('asr_ws_failure:') &&
          (errorMessage.contains('Socket is not connected') ||
              errorMessage.contains('closed') ||
              errorMessage.contains('cancel'))) {
        if (kDebugMode) {
          debugPrint('[VoiceMode] Suppressing benign ASR disconnect: $errorMessage');
        }
        return;
      }
      // Suppress asr_send_error from disconnect/teardown (e.g. mode switch stops stream → send cancelled).
      if (errorMessage.startsWith('asr_send_error:') &&
          (errorMessage.contains('cancelled') || errorMessage.contains('canceled'))) {
        if (kDebugMode) {
          debugPrint('[VoiceMode] Suppressing benign asr_send_error (teardown): $errorMessage');
        }
        return;
      }
      _delegate.onError(ErrorCopy.asrStartFailed);
    }
  }

  void _emitTelemetryMetric(
    String name,
    double value, {
    Map<String, Object?> dimensions = const <String, Object?>{},
  }) {
    dev.log(
      'native_audio_metric name=$name value=$value dimensions=$dimensions',
      name: 'VoiceTelemetry',
    );
  }

  /// Speak text with VAD suppression, then restart the inactivity timer.
  Future<void> speakAndResumeTimer(String text) async {
    await _speakWithSuppression(text);
    if (_currentState == VoiceState.listening && !_disposed) {
      _startInactivityTimer();
    }
  }

  /// Restart the inactivity timer only (no TTS). Use in manual mode after confirm.
  void resumeTimer() {
    if (_currentState == VoiceState.listening && !_disposed) {
      _startInactivityTimer();
    }
  }

  /// Release all resources permanently.
  Future<void> dispose() async {
    _disposed = true;
    _asrConnection.markDisposed();
    _isPushEndPending = false;
    _pushEndCompleter?.completeError(StateError('Orchestrator disposed'));
    _pushEndCompleter = null;
    _discardAsrFinalTextCount = 0;
    _pushToTalkAutoReleaseTimer?.cancel();
    _pushToTalkAutoReleaseTimer = null;
    await stopListening();
    await _disposeNativeSession();
  }

  // ======================== Inactivity Timer ========================

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _timeoutWarningTimer?.cancel();
    _inactivityTimer = Timer(inactivityTimeout, _onInactivityTimeout);
    // Pre-warning 30s before actual timeout
    final warningDelay = inactivityTimeout - timeoutWarningBefore;
    _timeoutWarningTimer = Timer(warningDelay, _onTimeoutWarning);
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _timeoutWarningTimer?.cancel();
    _timeoutWarningTimer = null;
  }

  void _onTimeoutWarning() {
    if (_disposed || _currentState != VoiceState.listening) return;
    _delegate.onTimeoutWarning();
    _speakWithSuppression(TtsTemplates.timeout());
  }

  void _onInactivityTimeout() {
    if (_disposed || _currentState == VoiceState.idle) return;
    dev.log(
      'Session timed out after ${inactivityTimeout.inMinutes}m',
      name: 'VoiceOrchestrator',
    );
    _currentState = VoiceState.idle;
    _delegate.onSessionTimeout();
  }

  // VAD 功能已移至原生层（barge-in 检测），不再需要 Flutter 层的 VAD

  // ======================== ASR Final Text ========================

  Future<void> _onAsrFinalText(String text) async {
    if (_disposed) return;
    if (kDebugMode) debugPrint('[ASRFlow] Processing final text: "$text"');
    if (text.trim().isEmpty) {
      if (kDebugMode) debugPrint('[ASRFlow] Empty final text, resetting to listening');
      _currentState = VoiceState.listening;
      _startInactivityTimer();
      _delegate.onContinueRecording();
      return;
    }

    // 原生 ASR 模式下，音频传输由原生层处理，不需要手动断开连接
    if (_disposed) return;

    if (_currentState == VoiceState.confirming) {
      await _handleConfirmingSpeech(text);
    } else {
      await _parseAndDeliver(text);
    }
  }

  // ======================== NLP Parsing ========================

  static final _punctuation = RegExp(r'[\s。！？，、…·""''「」（）,.!?;:-]');
  static const _fillerWords = {
    '嗯', '啊', '哦', '唔', '呃', '噢', '额', '嗯嗯', '呢',
    '哈', '嘿', '哎', '诶', '喂', '嘛', '吧',
    '咳咳', '咳咳咳', '哼', '哼哈',
  };

  bool _isFillerText(String text) {
    final stripped = text.replaceAll(_punctuation, '');
    return stripped.isEmpty || _fillerWords.contains(stripped);
  }

  /// Maps LlmParseException to user-facing copy; logs E-LLM-xxx in debug.
  String _userMessageForLlmError(String errorStr) {
    if (errorStr.contains('TimeoutException') ||
        errorStr.contains('Request timed out')) {
      if (kDebugMode) debugPrint('[LlmParse] E-LLM-001');
      return ErrorCopy.llmTimeout;
    }
    if (errorStr.contains('NetworkUnavailableException') ||
        errorStr.contains('Network unavailable')) {
      if (kDebugMode) debugPrint('[LlmParse] E-LLM-002');
      return ErrorCopy.llmNetwork;
    }
    if (errorStr.contains('RateLimitException') ||
        errorStr.contains('Rate limit')) {
      if (kDebugMode) debugPrint('[LlmParse] E-LLM-003');
      return ErrorCopy.llmRateLimit;
    }
    if (errorStr.contains('LLM parse failed') || errorStr.contains('422')) {
      if (kDebugMode) debugPrint('[LlmParse] E-LLM-004');
      return ErrorCopy.llmUnavailable;
    }
    if (kDebugMode) debugPrint('[LlmParse] E-LLM-005');
    return ErrorCopy.llmParseFailed;
  }

  Future<void> _parseAndDeliver(String text) async {
    if (_isFillerText(text)) {
      dev.log('Skipping filler text: "$text"', name: 'VoiceOrchestrator');
      _currentState = VoiceState.listening;
      _startInactivityTimer();
      _delegate.onContinueRecording();
      return;
    }
    try {
      final results = await _nlpOrchestrator.parse(text);
      if (_disposed) return;
      if (results.isEmpty) {
        _delegate.onError(ErrorCopy.llmParseFailed);
        _currentState = VoiceState.listening;
        _startInactivityTimer();
        return;
      }

      // Check if any result has an amount
      final hasAnyAmount = results.any((r) => r.amount != null);
      if (!hasAnyAmount) {
        // Check if result has any meaningful content (category or description)
        // If not, silently skip to avoid prompting user for meaningless input
        final hasAnyMeaningfulContent = results.any(
          (r) => (r.category != null && r.category!.isNotEmpty) ||
              (r.description != null && r.description!.isNotEmpty),
        );
        
        if (!hasAnyMeaningfulContent) {
          // No amount, category, or description - likely meaningless input
          // Silently skip similar to filler text handling
          if (kDebugMode) {
            debugPrint('[VoiceMode] No meaningful content found, silently skipping');
          }
          dev.log('Skipping meaningless input: "$text"', name: 'VoiceOrchestrator');
          _currentState = VoiceState.listening;
          _startInactivityTimer();
          _delegate.onContinueRecording();
          return;
        }
        
        // Has category or description but no amount - prompt user
        if (kDebugMode) {
          debugPrint('[VoiceMode] No amount found in parse results, showing original text');
        }
        _currentState = VoiceState.listening;
        _startInactivityTimer();
        _delegate.onFinalText(text, DraftBatch.empty());
        await _speakWithSuppression('没有输入金额，请重新输入');
        return;
      }

      _draftBatch = DraftBatch.fromResults(results);
      _currentState = VoiceState.confirming;
      _cancelInactivityTimer();
      _delegate.onFinalText(text, _draftBatch!);

      // TTS: single vs batch announcement (transfer has no category, still announce)
      if (_draftBatch!.isSingleItem) {
        final r = results.first;
        if (r.amount != null) {
          await _speakWithSuppression(
            TtsTemplates.confirm(
              category: r.category,
              type: r.type,
              amount: r.amount!,
            ),
          );
        }
      } else if (_draftBatch!.length <= 5) {
        final ttsItems = results
            .map((r) => (category: r.category, type: r.type, amount: r.amount))
            .toList();
        await _speakWithSuppression(
          TtsTemplates.batchConfirmation(ttsItems),
        );
      } else {
        final total = results.fold(0.0, (s, r) => s + (r.amount ?? 0));
        await _speakWithSuppression(
          TtsTemplates.batchSummary(count: results.length, total: total),
        );
      }
    } catch (e) {
      final message = e is LlmParseException
          ? _userMessageForLlmError(e.toString())
          : 'NLP parsing failed: $e';
      _delegate.onError(message);
      _currentState = VoiceState.listening;
      _startInactivityTimer();
    }
  }

  // ======================== Confirmation Handling ========================

  Future<void> _handleConfirmingSpeech(String text) async {
    if (_isCorrecting) return;
    if (_isFillerText(text)) {
      dev.log('Ignoring filler in confirming state: "$text"', name: 'VoiceOrchestrator');
      return;
    }

    final intent = _correctionHandler.classify(text);

    switch (intent) {
      case CorrectionIntent.confirm:
        await _handleConfirmAll();

      case CorrectionIntent.cancel:
        _handleCancelAll();

      case CorrectionIntent.confirmItem:
        await _handleConfirmItem(text);

      case CorrectionIntent.cancelItem:
        await _handleCancelItem(text);

      case CorrectionIntent.continueRecording:
        await _handleContinueRecording();

      case CorrectionIntent.exit:
        _handleExit();

      case CorrectionIntent.correction:
      case CorrectionIntent.newInput:
        await _handleCorrectionOrNewInput(text);
    }
  }

  Future<void> _handleConfirmAll() async {
    final batch = _draftBatch;
    if (batch == null) {
      _delegate.onConfirmTransaction();
      _currentState = VoiceState.listening;
      _startInactivityTimer();
      return;
    }

    _draftBatch = batch.confirmAll();
    _delegate.onDraftBatchUpdated(_draftBatch!);
    await _checkAutoSubmit();
  }

  void _handleCancelAll() {
    final batch = _draftBatch;
    if (batch == null) {
      _delegate.onCancelTransaction();
      _currentState = VoiceState.listening;
      _startInactivityTimer();
      return;
    }

    _draftBatch = batch.cancelAll();
    _delegate.onDraftBatchUpdated(_draftBatch!);
    _checkAutoSubmit();
  }

  Future<void> _handleConfirmItem(String text) async {
    final batch = _draftBatch;
    if (batch == null) return;

    final oneBasedIndex = _correctionHandler.extractItemIndex(text);
    if (oneBasedIndex == null) return;
    final zeroBasedIndex = oneBasedIndex - 1;

    if (zeroBasedIndex < 0 || zeroBasedIndex >= batch.length) return;

    _draftBatch = batch.confirmItem(zeroBasedIndex);
    _delegate.onDraftBatchUpdated(_draftBatch!);
    await _checkAutoSubmit();
  }

  Future<void> _handleCancelItem(String text) async {
    final batch = _draftBatch;
    if (batch == null) return;

    final oneBasedIndex = _correctionHandler.extractItemIndex(text);
    if (oneBasedIndex == null) return;
    final zeroBasedIndex = oneBasedIndex - 1;

    if (zeroBasedIndex < 0 || zeroBasedIndex >= batch.length) return;

    _draftBatch = batch.cancelItem(zeroBasedIndex);
    _delegate.onDraftBatchUpdated(_draftBatch!);
    await _checkAutoSubmit();
  }

  Future<void> _handleContinueRecording() async {
    final batch = _draftBatch;
    if (batch != null && batch.confirmedItems.isNotEmpty) {
      await _delegate.onBatchSaved(batch.confirmedItems);
    }
    _draftBatch = null;
    _currentState = VoiceState.listening;
    _startInactivityTimer();
    _delegate.onContinueRecording();
  }

  void _handleExit() {
    _draftBatch = null;
    _currentState = VoiceState.idle;
    _cancelInactivityTimer();
    _delegate.onExitSession();
  }

  Future<void> _handleCorrectionOrNewInput(String text) async {
    final batch = _draftBatch;
    if (batch == null) {
      // No existing batch, treat as new input
      await _parseAndDeliver(text);
      return;
    }

    // Check if all items are resolved but user wants to correct confirmed items
    final allResolved = batch.allResolved;
    final hasConfirmed = batch.confirmedItems.isNotEmpty;
    final intent = _correctionHandler.classify(text);

    if (allResolved && hasConfirmed && intent == CorrectionIntent.correction) {
      // User wants to correct confirmed items, reset them to pending
      final resetBatch = DraftBatch(
        items: batch.items.map((item) {
          if (item.status == DraftStatus.confirmed) {
            return item.copyWith(status: DraftStatus.pending);
          }
          return item;
        }).toList(),
        createdAt: batch.createdAt,
      );
      _draftBatch = resetBatch;
      // Ensure state remains confirming to show card
      _currentState = VoiceState.confirming;
      _delegate.onDraftBatchUpdated(_draftBatch!);
      // Continue with correction logic below
    }

    final pendingItems = _draftBatch!.pendingItems;
    if (pendingItems.isEmpty) {
      // All items resolved, treat as new input
      await _parseAndDeliver(text);
      return;
    }

    // Has pending items, treat as correction
    await _speakWithSuppression(TtsTemplates.correctionLoading());

    // Build pending-only mapping for index remapping
    final indexMap = <int, int>{};
    for (var i = 0; i < pendingItems.length; i++) {
      indexMap[i] = pendingItems[i].index;
    }

    final pendingBatch = DraftBatch(
      items: [
        for (var i = 0; i < pendingItems.length; i++)
          DraftTransaction(
            index: i,
            result: pendingItems[i].result,
          ),
      ],
    );

    _isCorrecting = true;
    try {
      final response = await _nlpOrchestrator.correct(text, pendingBatch);
      if (_disposed) return;

      switch (response.intent) {
        case dto.CorrectionIntent.correction:
          _applyCorrectionsToBatch(response, indexMap);
          // Ensure state remains confirming after correction to show card
          if (_currentState != VoiceState.confirming) {
            _currentState = VoiceState.confirming;
            _delegate.onStateChanged(VoiceState.confirming);
          }
          await _speakWithSuppression(TtsTemplates.correctionConfirm());

        case dto.CorrectionIntent.confirm:
          _handleConfirmAll();

        case dto.CorrectionIntent.cancel:
          _handleCancelAll();

        case dto.CorrectionIntent.append:
          _handleAppend(response);

        case dto.CorrectionIntent.unclear:
          await _speakWithSuppression(TtsTemplates.correctionFailed());
      }
    } catch (e) {
      final message = e is LlmParseException
          ? _userMessageForLlmError(e.toString())
          : 'NLP correction failed: $e';
      _delegate.onError(message);
      _currentState = VoiceState.listening;
      _startInactivityTimer();
    } finally {
      _isCorrecting = false;
    }
  }

  void _applyCorrectionsToBatch(
    dto.TransactionCorrectionResponse response,
    Map<int, int> indexMap,
  ) {
    var batch = _draftBatch;
    if (batch == null) return;

    for (final correction in response.corrections) {
      final originalIndex = indexMap[correction.index];
      if (originalIndex == null) continue;

      final itemIdx = batch!.items.indexWhere((t) => t.index == originalIndex);
      if (itemIdx == -1) continue;

      final current = batch.items[itemIdx].result;
      final fields = correction.updatedFields;

      final updated = current.copyWith(
        amount: fields['amount'] is num
            ? (fields['amount'] as num).toDouble()
            : null,
        category: fields['category'] as String?,
        type: fields['type'] as String?,
        description: fields['description'] as String?,
        date: fields['date'] as String?,
        account: fields['account'] as String?,
      );

      batch = batch.updateItem(originalIndex, updated);
    }

    _draftBatch = batch;
    _delegate.onDraftBatchUpdated(_draftBatch!);
  }

  void _handleAppend(dto.TransactionCorrectionResponse response) {
    final batch = _draftBatch;
    if (batch == null || response.corrections.isEmpty) return;

    final fields = response.corrections.first.updatedFields;
    final newResult = ParseResult(
      amount: fields['amount'] is num
          ? (fields['amount'] as num).toDouble()
          : null,
      category: fields['category'] as String?,
      type: (fields['type'] as String?) ?? 'EXPENSE',
      description: fields['description'] as String?,
      date: fields['date'] as String?,
      account: fields['account'] as String?,
      transferDirection: fields['transfer_direction'] as String?,
      counterparty: fields['counterparty'] as String?,
      confidence: response.confidence,
      source: ParseSource.llm,
    );

    if (newResult.amount == null || newResult.amount! <= 0) {
      _speakWithSuppression(TtsTemplates.appendNoAmount());
      return;
    }

    final updated = batch.append(newResult);
    if (updated == null) {
      _speakWithSuppression(TtsTemplates.batchLimitReached());
      return;
    }

    _draftBatch = updated;
    _delegate.onDraftBatchUpdated(_draftBatch!);
    _speakWithSuppression(
      TtsTemplates.batchAppended(displayIndex: updated.length),
    );
  }

  // ======================== Auto-Submit ========================

  Future<void> _checkAutoSubmit() async {
    final batch = _draftBatch;
    if (batch == null || !batch.allResolved) return;

    final confirmed = batch.confirmedItems;
    final valid = confirmed
        .where((t) =>
            t.result.amount != null && t.result.amount! > 0)
        .toList();
    _draftBatch = null;
    _currentState = VoiceState.listening;
    _startInactivityTimer();

    if (valid.isNotEmpty) {
      final saveOk = await _delegate.onBatchSaved(valid);
      if (saveOk) {
        _speakWithSuppression(TtsTemplates.batchSaved(count: valid.length));
        if (valid.length < confirmed.length) {
          _speakWithSuppression(
            TtsTemplates.batchSkippedNoAmount(count: confirmed.length - valid.length),
          );
        }
      }
      _delegate.onConfirmTransaction();
    } else if (confirmed.isNotEmpty) {
      _delegate.onCancelTransaction();
      _speakWithSuppression(
        TtsTemplates.batchSkippedNoAmount(count: confirmed.length),
      );
    } else {
      _delegate.onCancelTransaction();
    }
  }

}
