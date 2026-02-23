package com.spark.suikouji.audio

import android.content.Context
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

class AudioRuntimeController(
    private val context: Context,
    private val emitEvent: (String, Map<String, Any?>) -> Unit,
) {
    // Session-wide state snapshot exposed to Flutter.
    private val initialized = AtomicBoolean(false)
    private var currentSessionId: String? = null
    private var asrMuted: Boolean = false
    private var ttsPlaying: Boolean = false
    private var focusState: String = "idle"
    private var route: String = "speaker"
    private var mode: String = "auto"
    private var bargeInConfig = BargeInConfig()

    private var captureRuntime: AsrCaptureRuntime? = null
    private var focusRouteManager: FocusRouteManager? = null
    private var nativeTtsController: NativeTtsController? = null
    private var bargeInDetector: BargeInDetector? = null
    private var asrTransport: AsrNativeTransport? = null

    fun initializeSession(args: Map<String, Any?>): Map<String, Any?> {
        val sessionId = args["sessionId"] as? String
            ?: return mapOf("ok" to false, "error" to "missing_session_id")
        val platformConfig = args["platformConfig"] as? Map<*, *>
        val requestedMode = args["mode"] as? String ?: mode
        val enableNativeCapture =
            platformConfig?.get("enableNativeCapture") as? Boolean ?: (requestedMode != "keyboard")

        mode = requestedMode
        // Lazy-create all components once, then keep them for the whole session.
        ensureComponents()
        // Current Flutter orchestrator still owns ASR capture path. Keep native capture
        // opt-in to avoid double AudioRecord sessions and mic contention.
        if (enableNativeCapture) {
            try {
                captureRuntime?.start()
            } catch (e: IllegalStateException) {
                emitRuntimeError("audio_record_init_failed", "Failed to initialize AudioRecord: ${e.message}")
                return mapOf("ok" to false, "error" to "audio_record_init_failed", "message" to (e.message ?: "Unknown error"))
            }
        }
        currentSessionId = sessionId
        initialized.set(true)
        route = focusRouteManager?.getRoute() ?: route
        emitEvent(
            "runtimeInitialized",
            mapOf(
                "sessionId" to sessionId,
                "timestamp" to System.currentTimeMillis(),
                "data" to mapOf("focusState" to focusState, "route" to route),
            ),
        )
        return mapOf(
            "ok" to true,
            "runtimeState" to "ready",
            "capabilities" to listOf(
                "asr_gate",
                "tts_lifecycle",
                "barge_in_events",
                "lifecycle_snapshot",
            ),
        )
    }

    fun disposeSession(args: Map<String, Any?>): Map<String, Any?> {
        val sessionId = args["sessionId"] as? String ?: currentSessionId
        if (sessionId != null && sessionId == currentSessionId) {
            captureRuntime?.stop()
            asrTransport?.disconnect()
            nativeTtsController?.release()
            focusRouteManager?.abandonPlaybackFocus()
            currentSessionId = null
            asrMuted = false
            ttsPlaying = false
            focusState = "idle"
            initialized.set(false)
            captureRuntime = null
            nativeTtsController = null
            focusRouteManager = null
            bargeInDetector = null
            asrTransport = null
        }
        return mapOf("ok" to true)
    }

    fun startAsrStream(args: Map<String, Any?>): Map<String, Any?> {
        ensureComponents()
        val token = args["token"] as? String
            ?: return mapOf("ok" to false, "error" to "missing_token")
        val wsUrl = args["wsUrl"] as? String
            ?: return mapOf("ok" to false, "error" to "missing_ws_url")
        val model = args["model"] as? String
            ?: return mapOf("ok" to false, "error" to "missing_model")
        val useServerVad = mode != "pushToTalk"
        val silenceDurationMs = (args["vadSilenceDurationMs"] as? Number)?.toInt() ?: 1000
        Log.d("AudioRuntime", "startAsrStream mode=$mode useServerVad=$useServerVad silenceDurationMs=$silenceDurationMs")
        asrTransport?.connect(
            token = token,
            wsUrl = wsUrl,
            model = model,
            useServerVad = useServerVad,
            silenceDurationMs = silenceDurationMs,
        )
        try {
            captureRuntime?.start()
        } catch (e: IllegalStateException) {
            emitRuntimeError("audio_record_start_failed", "Failed to start AudioRecord: ${e.message}")
            return mapOf("ok" to false, "error" to "audio_record_start_failed", "message" to (e.message ?: "Unknown error"))
        }
        return mapOf("ok" to true)
    }

    fun commitAsr(): Map<String, Any?> {
        asrTransport?.commit()
        return mapOf("ok" to true)
    }

    fun stopAsrStream(): Map<String, Any?> {
        asrTransport?.disconnect()
        return mapOf("ok" to true)
    }

    fun setAsrMuted(args: Map<String, Any?>): Map<String, Any?> {
        asrMuted = args["muted"] as? Boolean ?: asrMuted
        captureRuntime?.setAsrMuted(asrMuted)
        val sessionId = currentSessionId ?: ""
        emitEvent(
            "asrMuteStateChanged",
            mapOf(
                "sessionId" to sessionId,
                "timestamp" to System.currentTimeMillis(),
                "data" to mapOf("asrMuted" to asrMuted),
            ),
        )
        return mapOf("ok" to true, "muted" to asrMuted)
    }

    fun playTts(args: Map<String, Any?>): Map<String, Any?> {
        ensureComponents()
        ttsPlaying = true
        // Critical order: mute ASR input first, then request focus, then speak.
        setAsrMuted(mapOf("muted" to true))
        focusRouteManager?.requestPlaybackFocus()
        val sessionId = currentSessionId ?: ""
        val requestId = args["requestId"] as? String
        val text = args["text"] as? String ?: ""
        val locale = args["locale"] as? String ?: "zh-CN"
        val speechRate = (args["speechRate"] as? Number)?.toDouble() ?: 1.0
        val ok = nativeTtsController?.play(
            requestId = requestId,
            text = text,
            speechRate = speechRate,
            locale = locale,
        ) ?: false
        if (!ok) {
            ttsPlaying = false
            setAsrMuted(mapOf("muted" to false))
            focusRouteManager?.abandonPlaybackFocus()
            emitRuntimeError("tts_not_ready", "Native TTS engine not ready")
            return mapOf("ok" to false, "requestId" to requestId)
        }
        return mapOf("ok" to true, "requestId" to requestId)
    }

    fun stopTts(args: Map<String, Any?>): Map<String, Any?> {
        ensureComponents()
        nativeTtsController?.stop(args["reason"] as? String ?: "manual_stop")
        ttsPlaying = false
        // Critical order: stop playback -> unmute ASR -> release focus.
        setAsrMuted(mapOf("muted" to false))
        focusRouteManager?.abandonPlaybackFocus()
        val sessionId = currentSessionId ?: ""
        val requestId = args["requestId"] as? String
        emitEvent(
            "ttsStopped",
            mapOf(
                "sessionId" to sessionId,
                "requestId" to requestId,
                "timestamp" to System.currentTimeMillis(),
                "data" to mapOf("ttsPlaying" to false, "canAutoResume" to true),
            ),
        )
        return mapOf("ok" to true)
    }

    fun setBargeInConfig(args: Map<String, Any?>): Map<String, Any?> {
        bargeInConfig = BargeInConfig(
            enabled = args["enabled"] as? Boolean ?: bargeInConfig.enabled,
            energyThreshold = (args["energyThreshold"] as? Number)?.toDouble()
                ?: bargeInConfig.energyThreshold,
            minSpeechMs = (args["minSpeechMs"] as? Number)?.toInt()
                ?: bargeInConfig.minSpeechMs,
            cooldownMs = (args["cooldownMs"] as? Number)?.toInt()
                ?: bargeInConfig.cooldownMs,
        )
        bargeInDetector?.updateConfig(bargeInConfig)
        return mapOf("ok" to true, "enabled" to bargeInConfig.enabled)
    }

    fun getDuplexStatus(): Map<String, Any?> {
        return mapOf(
            "captureActive" to (captureRuntime?.isRunning() == true),
            "asrMuted" to asrMuted,
            "ttsPlaying" to ttsPlaying,
            "focusState" to focusState,
            "route" to route,
            "lastError" to null,
        )
    }

    fun switchInputMode(args: Map<String, Any?>): Map<String, Any?> {
        val newMode = args["mode"] as? String ?: mode
        val oldMode = mode
        mode = newMode

        when (newMode) {
            "keyboard" -> {
                // 停止 ASR stream，停止音频捕获
                asrTransport?.disconnect()
                captureRuntime?.stop()
                setAsrMuted(mapOf("muted" to true))
            }
            "pushToTalk" -> {
                // 如果之前是 auto 模式，captureRuntime 可能在运行，需要停止它
                // pushToTalk 模式下，captureRuntime 只在 pushStart 时启动
                if (captureRuntime?.isRunning() == true) {
                    captureRuntime?.stop()
                }
                // 保持 ASR stream 运行，但默认 mute ASR
                // 只有在 Flutter 层调用 pushStart 时才 unmute
                setAsrMuted(mapOf("muted" to true))
                // 禁用 barge-in（pushToTalk 模式下不需要自动 VAD）
                bargeInConfig = bargeInConfig.copy(enabled = false)
                bargeInDetector?.updateConfig(bargeInConfig)
                // Do not send session.update — server rejects second update and disconnects.
                // PushToTalk is enforced by client: mute when not holding, commit on pushEnd only.
            }
            "auto" -> {
                // 如果之前是 keyboard 或 pushToTalk 模式，captureRuntime 可能已停止
                // 需要确保 captureRuntime 运行（auto 模式需要持续监听）
                ensureComponents()
                if (captureRuntime?.isRunning() != true) {
                    try {
                        captureRuntime?.start()
                    } catch (e: IllegalStateException) {
                        emitRuntimeError("audio_record_start_failed", "Failed to start AudioRecord in auto mode: ${e.message}")
                        mode = oldMode
                        return mapOf(
                            "ok" to false,
                            "error" to "audio_record_start_failed",
                            "message" to (e.message ?: "Unknown error"),
                            "mode" to oldMode,
                        )
                    }
                }
                // 启用自动 VAD（仅当 capture 已成功启动，否则 ASR 无音频帧）
                setAsrMuted(mapOf("muted" to false))
                bargeInConfig = bargeInConfig.copy(enabled = true)
                bargeInDetector?.updateConfig(bargeInConfig)
                // Do not send session.update — server rejects second update and disconnects.
                // Server already has server_vad from initial connect.
            }
        }

        return mapOf("ok" to true, "mode" to mode)
    }

    fun startCapture(args: Map<String, Any?>): Map<String, Any?> {
        ensureComponents()
        if (captureRuntime?.isRunning() != true) {
            try {
                captureRuntime?.start()
            } catch (e: IllegalStateException) {
                emitRuntimeError("audio_record_start_failed", "Failed to start AudioRecord: ${e.message}")
                return mapOf("ok" to false, "error" to "audio_record_start_failed", "message" to (e.message ?: "Unknown error"))
            }
        }
        return mapOf("ok" to true)
    }

    fun stopCapture(args: Map<String, Any?>): Map<String, Any?> {
        captureRuntime?.stop()
        return mapOf("ok" to true)
    }

    fun getLifecycleSnapshot(): Map<String, Any?> {
        return mapOf(
            "appState" to "foreground",
            "captureActive" to (captureRuntime?.isRunning() == true),
            "asrMuted" to asrMuted,
            "ttsPlaying" to ttsPlaying,
            "focusState" to focusState,
            "route" to route,
            "bargeInConfig" to mapOf("enabled" to true),
        )
    }

    fun restoreLifecycleSnapshot(args: Map<String, Any?>): Map<String, Any?> {
        val snapshot = args["snapshot"] as? Map<*, *>
        asrMuted = snapshot?.get("asrMuted") as? Boolean ?: asrMuted
        captureRuntime?.setAsrMuted(asrMuted)
        ttsPlaying = snapshot?.get("ttsPlaying") as? Boolean ?: ttsPlaying
        focusState = snapshot?.get("focusState") as? String ?: focusState
        route = snapshot?.get("route") as? String ?: route
        return mapOf("ok" to true, "restoredFields" to listOf("asrMuted", "ttsPlaying", "focusState", "route"))
    }

    private fun ensureComponents() {
        if (captureRuntime != null &&
            focusRouteManager != null &&
            nativeTtsController != null &&
            bargeInDetector != null &&
            asrTransport != null) {
            return
        }

        bargeInDetector = BargeInDetector(
            onTriggered = {
                if (!ttsPlaying || !bargeInConfig.enabled) return@BargeInDetector
                val sid = currentSessionId ?: ""
                emitEvent(
                    "bargeInTriggered",
                    mapOf(
                        "sessionId" to sid,
                        "timestamp" to System.currentTimeMillis(),
                        "data" to mapOf(
                            "triggerSource" to "energy_vad",
                            "route" to route,
                            "focusState" to focusState,
                            "canAutoResume" to true,
                        ),
                    ),
                )
                // Barge-in main path: trigger -> stop TTS -> resume ASR input.
                stopTts(mapOf("reason" to "barge_in"))
                emitEvent(
                    "bargeInCompleted",
                    mapOf(
                        "sessionId" to sid,
                        "timestamp" to System.currentTimeMillis(),
                        "data" to mapOf("success" to true, "canAutoResume" to true),
                    ),
                )
            },
        ).also {
            it.updateConfig(bargeInConfig)
        }

        // Create asrTransport before captureRuntime so the capture callback always sees a non-null transport.
        asrTransport = AsrNativeTransport(
            onInterimText = { text ->
                val sid = currentSessionId ?: ""
                emitEvent(
                    "asrInterimText",
                    mapOf(
                        "sessionId" to sid,
                        "timestamp" to System.currentTimeMillis(),
                        "data" to mapOf("text" to text),
                    ),
                )
            },
            onFinalText = { text ->
                val sid = currentSessionId ?: ""
                emitEvent(
                    "asrFinalText",
                    mapOf(
                        "sessionId" to sid,
                        "timestamp" to System.currentTimeMillis(),
                        "data" to mapOf("text" to text),
                    ),
                )
            },
            onError = { message ->
                emitRuntimeError("asr_ws_error", message)
            },
        )

        captureRuntime = AsrCaptureRuntime(
            context = context,
            onAudioFrame = { frame ->
                bargeInDetector?.onFrame(frame, ttsPlaying)
                if (!asrMuted) asrTransport?.sendAudioFrame(frame)
            }
        ).also { it.setAsrMuted(asrMuted) }

        focusRouteManager = FocusRouteManager(context) { newFocusState, canAutoResume ->
            focusState = newFocusState
            route = focusRouteManager?.getRoute() ?: route
            val sid = currentSessionId ?: ""
            emitEvent(
                "audioFocusChanged",
                mapOf(
                    "sessionId" to sid,
                    "timestamp" to System.currentTimeMillis(),
                    "data" to mapOf(
                        "focusState" to newFocusState,
                        "route" to route,
                        "canAutoResume" to canAutoResume,
                    ),
                ),
            )
        }

        nativeTtsController = NativeTtsController(
            context = context,
            onStarted = { requestId ->
                val sid = currentSessionId ?: ""
                emitEvent(
                    "ttsStarted",
                    mapOf(
                        "sessionId" to sid,
                        "requestId" to requestId,
                        "timestamp" to System.currentTimeMillis(),
                        "data" to mapOf("ttsPlaying" to true, "route" to route, "focusState" to focusState),
                    ),
                )
            },
            onCompleted = { requestId, success, error ->
                ttsPlaying = false
                // Always restore recognizer path after playback exits (success/error/cancel).
                setAsrMuted(mapOf("muted" to false))
                focusRouteManager?.abandonPlaybackFocus()
                val sid = currentSessionId ?: ""
                if (success) {
                    emitEvent(
                        "ttsCompleted",
                        mapOf(
                            "sessionId" to sid,
                            "requestId" to requestId,
                            "timestamp" to System.currentTimeMillis(),
                            "data" to mapOf("ttsPlaying" to false, "canAutoResume" to true),
                        ),
                    )
                } else {
                    val normalized = ErrorMapper.normalize(
                        rawCode = error,
                        fallbackMessage = error ?: "unknown",
                    )
                    emitEvent(
                        "ttsError",
                        mapOf(
                            "sessionId" to sid,
                            "requestId" to requestId,
                            "timestamp" to System.currentTimeMillis(),
                            "error" to mapOf(
                                "code" to normalized.code,
                                "message" to normalized.message,
                                "rawCode" to normalized.rawCode,
                            ),
                            "data" to mapOf("ttsPlaying" to false, "canAutoResume" to true),
                        ),
                    )
                }
            },
            onInitDiagnostics = { diagnostics ->
                val sid = currentSessionId ?: ""
                emitEvent(
                    "ttsInitDiagnostics",
                    mapOf(
                        "sessionId" to sid,
                        "timestamp" to System.currentTimeMillis(),
                        "data" to diagnostics,
                    ),
                )
            },
            isAsrActive = { asrTransport?.isConnected() ?: false },
            isAudioRecordActive = { captureRuntime?.isRunning() ?: false },
        )
    }

    private fun emitRuntimeError(code: String, message: String) {
        val normalized = ErrorMapper.normalize(rawCode = code, fallbackMessage = message)
        val sid = currentSessionId ?: ""
        emitEvent(
            "runtimeError",
            mapOf(
                "sessionId" to sid,
                "timestamp" to System.currentTimeMillis(),
                "error" to mapOf(
                    "code" to normalized.code,
                    "message" to normalized.message,
                    "rawCode" to normalized.rawCode,
                ),
                "data" to mapOf("focusState" to focusState, "route" to route),
            ),
        )
    }
}
