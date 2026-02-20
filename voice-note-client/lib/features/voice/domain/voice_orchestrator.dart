import 'dart:async';
import 'dart:developer' as dev;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/dto/transaction_correction_response.dart'
    as dto;
import '../../../core/tts/tts_service.dart';
import '../../../core/tts/tts_templates.dart';
import '../data/asr_repository.dart';
import '../data/asr_websocket_service.dart';
import '../data/audio_capture_service.dart';
import '../data/vad_service.dart';
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
  void onBatchSaved(List<DraftTransaction> confirmedItems);
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
}

/// Orchestrates the full voice pipeline: AudioCapture → VAD → ASR → NLP.
///
/// Manages three input modes:
/// - **auto**: VAD-controlled ASR connection lifecycle (zero cloud cost in silence)
/// - **pushToTalk**: Manual start/stop via button press
/// - **keyboard**: No audio services, text-only input
class VoiceOrchestrator {
  final NlpOrchestrator _nlpOrchestrator;
  final VoiceCorrectionHandler _correctionHandler;
  final VoiceOrchestratorDelegate _delegate;
  final TtsService? _ttsService;
  final AsrConnectionManager _asrConnection;

  // Owned services — created/destroyed per session
  AudioCaptureService? _audioCapture;
  VadService? _vadService;
  AsrWebSocketService? _asrService;

  // Stream subscriptions for VAD (ASR subscriptions managed by AsrConnectionManager)
  final List<StreamSubscription<dynamic>> _vadSubscriptions = [];

  VoiceState _currentState = VoiceState.idle;
  bool _disposed = false;

  DraftBatch? _draftBatch;

  // TTS VAD suppression flag
  bool _isTtsSpeaking = false;

  // Inactivity timeout
  static const Duration inactivityTimeout = Duration(minutes: 3);
  static const Duration timeoutWarningBefore = Duration(seconds: 30);
  Timer? _inactivityTimer;
  Timer? _timeoutWarningTimer;

  // Correction in-flight guard — blocks confirm/cancel during LLM request
  bool _isCorrecting = false;

  // PTT timing — discard recordings shorter than threshold
  static const Duration minPttDuration = Duration(milliseconds: 600);
  static const Duration pttAsrTimeout = Duration(seconds: 8);
  DateTime? _pttStartTime;
  Timer? _pttTimeoutTimer;

  // VAD misfire tracking
  static const int maxConsecutiveMisfires = 3;
  int _consecutiveMisfires = 0;

  VoiceOrchestrator({
    required AsrRepository asrRepository,
    required NlpOrchestrator nlpOrchestrator,
    required VoiceCorrectionHandler correctionHandler,
    required VoiceOrchestratorDelegate delegate,
    TtsService? ttsService,
    AudioCaptureService? audioCapture,
    VadService? vadService,
    AsrWebSocketService? asrService,
    AsrConnectionManager? asrConnectionManager,
  }) : _nlpOrchestrator = nlpOrchestrator,
       _correctionHandler = correctionHandler,
       _delegate = delegate,
       _ttsService = ttsService,
       _audioCapture = audioCapture,
       _vadService = vadService,
       _asrService = asrService,
       _asrConnection = asrConnectionManager ??
           AsrConnectionManager(asrRepository: asrRepository) {
    _asrConnection.onInterimText =
        (String text) => _delegate.onInterimText(text);
    _asrConnection.onFinalText = (String text) => _onAsrFinalText(text);
    _asrConnection.onError = (String msg) => _delegate.onError(msg);
    _asrConnection.onReconnectFailed = () {
      _delegate.onError('ASR 连接中断，重连失败');
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
  Future<void> startListening(VoiceInputMode mode) async {
    if (kDebugMode) debugPrint('[VoiceInit] startListening(mode=$mode)');
    if (mode == VoiceInputMode.keyboard) {
      if (kDebugMode) debugPrint('[VoiceInit] Keyboard mode — skipping audio init');
      return;
    }

    try {
      _audioCapture ??= AudioCaptureService();
      _vadService ??= VadService();
      _asrService ??= AsrWebSocketService();
      _asrConnection.configure(
        asrService: _asrService,
        audioCapture: _audioCapture,
      );

      if (kDebugMode) debugPrint('[VoiceInit] Step 1/4: Starting audio capture...');
      await _audioCapture!.start(preBufferMs: 1000);

      if (kDebugMode) debugPrint('[VoiceInit] Step 2/4: Subscribing to VAD events...');
      _subscribeToVadEvents();

      if (kDebugMode) debugPrint('[VoiceInit] Step 3/4: Starting VAD...');
      await _vadService!.start(audioStream: _audioCapture!.audioStream);

      _currentState = VoiceState.listening;
      _startInactivityTimer();
      if (kDebugMode) debugPrint('[VoiceInit] Step 4/4: Pipeline ready, state=listening');

      if (kDebugMode) debugPrint('[VoiceInit] Speaking welcome TTS...');
      await _speakWithSuppression(TtsTemplates.welcome());
      if (kDebugMode) debugPrint('[VoiceInit] startListening() complete');
    } catch (e) {
      if (kDebugMode) debugPrint('[VoiceInit] FAILED: $e');
      _delegate.onError('Failed to start listening: $e');
    }
  }

  /// Start push-to-talk: connect ASR immediately and stream audio.
  Future<void> pushStart() async {
    _cancelInactivityTimer();
    _pttStartTime = clock.now();
    try {
      _audioCapture ??= AudioCaptureService();
      _asrService ??= AsrWebSocketService();
      _asrConnection.configure(
        asrService: _asrService,
        audioCapture: _audioCapture,
      );

      await _audioCapture!.start();
      _currentState = VoiceState.recognizing;
      _delegate.onSpeechDetected();
      final ok = await _asrConnection.connectAndStream();
      if (!ok) {
        _currentState = VoiceState.listening;
        _pttStartTime = null;
        _startInactivityTimer();
      }
    } catch (e) {
      _pttStartTime = null;
      _currentState = VoiceState.listening;
      _startInactivityTimer();
      _delegate.onError('Push-to-talk start failed: $e');
    }
  }

  /// End push-to-talk: commit audio and process result.
  /// If held too briefly, discards the recording.
  void pushEnd() {
    final startTime = _pttStartTime;
    _pttStartTime = null;
    if (startTime == null) {
      dev.log('pushEnd without pushStart, ignoring', name: 'VoiceOrchestrator');
      return;
    }
    final held = clock.now().difference(startTime);
    if (held < minPttDuration) {
      dev.log(
        'PTT too short (${held.inMilliseconds}ms < ${minPttDuration.inMilliseconds}ms), discarding',
        name: 'VoiceOrchestrator',
      );
      _currentState = VoiceState.listening;
      _startInactivityTimer();
      _delegate.onContinueRecording();
      _delegate.onError('说话时间太短，请按住按钮说话');
      return;
    }
    _asrConnection.commit();

    _pttTimeoutTimer?.cancel();
    _pttTimeoutTimer = Timer(pttAsrTimeout, _onPttAsrTimeout);
  }

  void _onPttAsrTimeout() {
    if (_disposed || _currentState != VoiceState.recognizing) return;
    dev.log(
      'PTT ASR timeout after ${pttAsrTimeout.inSeconds}s, resetting to listening',
      name: 'VoiceOrchestrator',
    );
    _currentState = VoiceState.listening;
    _startInactivityTimer();
    _delegate.onContinueRecording();
    _delegate.onError('识别超时，请重试');
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

  /// Stop all audio services and go back to idle.
  Future<void> stopListening() async {
    _draftBatch = null;
    _asrConnection.resetReconnectAttempts();
    _consecutiveMisfires = 0;
    _isTtsSpeaking = false;
    _pttStartTime = null;
    _pttTimeoutTimer?.cancel();
    _pttTimeoutTimer = null;
    _cancelInactivityTimer();
    _cancelVadSubscriptions();
    _asrConnection.cancelSubscriptions();
    try {
      await _asrConnection.disconnect();
    } catch (e) {
      dev.log('ASR disconnect error during cleanup: $e', name: 'VoiceOrchestrator', level: 900);
    }
    try {
      await _vadService?.stop();
    } catch (e) {
      dev.log('VAD stop error during cleanup: $e', name: 'VoiceOrchestrator', level: 900);
    }
    try {
      await _audioCapture?.stop();
    } catch (e) {
      dev.log('Audio capture stop error during cleanup: $e', name: 'VoiceOrchestrator', level: 900);
    }
    _currentState = VoiceState.idle;
  }

  /// Speak text with VAD suppression — ignore VAD events during playback.
  Future<void> _speakWithSuppression(String text) async {
    final tts = _ttsService;
    if (tts == null || !tts.enabled || !tts.available) {
      if (kDebugMode) {
        debugPrint(
          '[TTSFlow] _speakWithSuppression SKIPPED: '
          'tts=${tts != null ? "exists" : "null"}, '
          'enabled=${tts?.enabled}, available=${tts?.available}',
        );
      }
      return;
    }

    _isTtsSpeaking = true;
    if (kDebugMode) debugPrint('[TTSFlow] Speaking with VAD suppression: "$text"');
    try {
      await tts.speak(text);
      if (kDebugMode) debugPrint('[TTSFlow] Speech done, resuming VAD');
    } catch (e) {
      if (kDebugMode) debugPrint('[TTSFlow] Speak FAILED (degrading): $e');
    } finally {
      _isTtsSpeaking = false;
    }
  }

  /// Speak text with VAD suppression, then restart the inactivity timer.
  Future<void> speakAndResumeTimer(String text) async {
    await _speakWithSuppression(text);
    if (_currentState == VoiceState.listening && !_disposed) {
      _startInactivityTimer();
    }
  }

  /// Release all resources permanently.
  Future<void> dispose() async {
    _disposed = true;
    _asrConnection.markDisposed();
    await stopListening();
    try {
      await _asrService?.dispose();
    } catch (e) {
      dev.log('ASR dispose error: $e', name: 'VoiceOrchestrator', level: 900);
    }
    try {
      await _vadService?.dispose();
    } catch (e) {
      dev.log('VAD dispose error: $e', name: 'VoiceOrchestrator', level: 900);
    }
    try {
      await _audioCapture?.dispose();
    } catch (e) {
      dev.log('AudioCapture dispose error: $e', name: 'VoiceOrchestrator', level: 900);
    }
    _asrService = null;
    _vadService = null;
    _audioCapture = null;
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

  // ======================== VAD Events ========================

  void _subscribeToVadEvents() {
    final vad = _vadService;
    if (vad == null) {
      dev.log('[VADFlow] Cannot subscribe — vadService is null!', name: 'VoiceOrchestrator');
      return;
    }

    if (kDebugMode) debugPrint('[VADFlow] Subscribing to VAD events...');
    _vadSubscriptions.add(
      vad.onSpeechStart.listen((_) {
        if (kDebugMode) debugPrint('[VADFlow] >>> onSpeechStart (initial, may be misfire)');
      }),
    );
    _vadSubscriptions.add(
      vad.onRealSpeechStart.listen((_) => _onRealSpeechStart()),
    );
    _vadSubscriptions.add(vad.onSpeechEnd.listen((_) => _onSpeechEnd()));
    _vadSubscriptions.add(vad.onVADMisfire.listen((_) => _onVadMisfire()));
    int frameCount = 0;
    _vadSubscriptions.add(
      vad.onFrameProcessed.listen((frame) {
        frameCount++;
        if (frameCount <= 5 || frameCount % 100 == 0) {
          if (kDebugMode) {
            debugPrint(
              '[VADFlow] Frame #$frameCount: speech=${frame.isSpeech.toStringAsFixed(3)}, '
              'notSpeech=${frame.notSpeech.toStringAsFixed(3)}',
            );
          }
        }
      }),
    );
    _vadSubscriptions.add(
      vad.onError.listen((err) {
        if (kDebugMode) debugPrint('[VADFlow] ERROR: $err');
        _delegate.onError('VAD error: $err');
      }),
    );
    if (kDebugMode) debugPrint('[VADFlow] Subscribed to all VAD events');
  }

  Future<void> _onRealSpeechStart() async {
    if (kDebugMode) debugPrint('[VADFlow] >>> onRealSpeechStart — speech confirmed!');

    // Capture ring-buffer snapshot IMMEDIATELY before any async work.
    // The ring buffer holds only 500ms; token fetch + WebSocket connect can
    // take 200-500ms, causing early speech audio to be evicted if we drain
    // inside connectAndStream() instead.
    final preBuffer = _audioCapture?.drainPreBuffer() ?? [];
    if (kDebugMode) debugPrint('[VADFlow] Pre-buffer captured: ${preBuffer.length} chunks');

    if (_isTtsSpeaking) {
      if (kDebugMode) debugPrint('[VADFlow] Barge-in: stopping TTS');
      try {
        await _ttsService?.stop();
      } catch (e) {
        dev.log('TTS stop error during barge-in: $e', name: 'VoiceOrchestrator', level: 900);
      }
      _isTtsSpeaking = false;
    }

    _cancelInactivityTimer();
    _consecutiveMisfires = 0;
    _currentState = VoiceState.recognizing;
    _delegate.onSpeechDetected();
    final ok = await _asrConnection.connectAndStream(capturedPreBuffer: preBuffer);
    if (!ok) _currentState = VoiceState.listening;
  }

  void _onSpeechEnd() {
    if (kDebugMode) debugPrint('[VADFlow] >>> onSpeechEnd — committing audio to ASR');
    _asrConnection.commit();
  }

  void _onVadMisfire() {
    _consecutiveMisfires++;
    dev.log('VAD misfire #$_consecutiveMisfires', name: 'VoiceOrchestrator');
    if (_consecutiveMisfires >= maxConsecutiveMisfires) {
      _consecutiveMisfires = 0;
      _delegate.onSuggestPushToTalk();
    }
  }

  // ======================== ASR Final Text ========================

  Future<void> _onAsrFinalText(String text) async {
    if (_disposed) return;
    if (kDebugMode) debugPrint('[ASRFlow] Processing final text: "$text"');
    _pttTimeoutTimer?.cancel();
    _pttTimeoutTimer = null;
    if (text.trim().isEmpty) {
      if (kDebugMode) debugPrint('[ASRFlow] Empty final text, resetting to listening');
      _currentState = VoiceState.listening;
      _startInactivityTimer();
      _delegate.onContinueRecording();
      return;
    }

    await _asrConnection.disconnect();
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
  };

  bool _isFillerText(String text) {
    final stripped = text.replaceAll(_punctuation, '');
    return stripped.isEmpty || _fillerWords.contains(stripped);
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
        _delegate.onError('NLP parsing returned empty results');
        _currentState = VoiceState.listening;
        _startInactivityTimer();
        return;
      }

      _draftBatch = DraftBatch.fromResults(results);
      _currentState = VoiceState.confirming;
      _cancelInactivityTimer();
      _delegate.onFinalText(text, _draftBatch!);

      // TTS: single vs batch announcement
      if (_draftBatch!.isSingleItem) {
        final r = results.first;
        if (r.amount != null && r.category != null) {
          await _speakWithSuppression(
            TtsTemplates.confirm(
              category: r.category!,
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
      _delegate.onError('NLP parsing failed: $e');
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
        _handleConfirmAll();

      case CorrectionIntent.cancel:
        _handleCancelAll();

      case CorrectionIntent.confirmItem:
        _handleConfirmItem(text);

      case CorrectionIntent.cancelItem:
        _handleCancelItem(text);

      case CorrectionIntent.continueRecording:
        _handleContinueRecording();

      case CorrectionIntent.exit:
        _handleExit();

      case CorrectionIntent.correction:
      case CorrectionIntent.newInput:
        await _handleCorrectionOrNewInput(text);
    }
  }

  void _handleConfirmAll() {
    final batch = _draftBatch;
    if (batch == null) {
      _delegate.onConfirmTransaction();
      _currentState = VoiceState.listening;
      _startInactivityTimer();
      return;
    }

    _draftBatch = batch.confirmAll();
    _delegate.onDraftBatchUpdated(_draftBatch!);
    _checkAutoSubmit();
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

  void _handleConfirmItem(String text) {
    final batch = _draftBatch;
    if (batch == null) return;

    final oneBasedIndex = _correctionHandler.extractItemIndex(text);
    if (oneBasedIndex == null) return;
    final zeroBasedIndex = oneBasedIndex - 1;

    if (zeroBasedIndex < 0 || zeroBasedIndex >= batch.length) return;

    _draftBatch = batch.confirmItem(zeroBasedIndex);
    _delegate.onDraftBatchUpdated(_draftBatch!);
    _checkAutoSubmit();
  }

  void _handleCancelItem(String text) {
    final batch = _draftBatch;
    if (batch == null) return;

    final oneBasedIndex = _correctionHandler.extractItemIndex(text);
    if (oneBasedIndex == null) return;
    final zeroBasedIndex = oneBasedIndex - 1;

    if (zeroBasedIndex < 0 || zeroBasedIndex >= batch.length) return;

    _draftBatch = batch.cancelItem(zeroBasedIndex);
    _delegate.onDraftBatchUpdated(_draftBatch!);
    _checkAutoSubmit();
  }

  void _handleContinueRecording() {
    final batch = _draftBatch;
    if (batch != null && batch.confirmedItems.isNotEmpty) {
      _delegate.onBatchSaved(batch.confirmedItems);
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
      await _parseAndDeliver(text);
      return;
    }

    await _speakWithSuppression(TtsTemplates.correctionLoading());

    final pendingItems = batch.pendingItems;
    if (pendingItems.isEmpty) {
      await _parseAndDeliver(text);
      return;
    }

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
      _delegate.onError('NLP correction failed: $e');
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
      confidence: response.confidence,
      source: ParseSource.llm,
    );

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

  void _checkAutoSubmit() {
    final batch = _draftBatch;
    if (batch == null || !batch.allResolved) return;

    final confirmed = batch.confirmedItems;
    _draftBatch = null;
    _currentState = VoiceState.listening;
    _startInactivityTimer();

    if (confirmed.isNotEmpty) {
      _delegate.onBatchSaved(confirmed);
      _speakWithSuppression(TtsTemplates.batchSaved(count: confirmed.length));
      _delegate.onConfirmTransaction();
    } else {
      _delegate.onCancelTransaction();
    }
  }

  // ======================== Subscription Management ========================

  void _cancelVadSubscriptions() {
    for (final sub in _vadSubscriptions) {
      sub.cancel();
    }
    _vadSubscriptions.clear();
  }
}
