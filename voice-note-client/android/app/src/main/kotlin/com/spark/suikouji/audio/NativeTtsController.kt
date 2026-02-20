package com.spark.suikouji.audio

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

class NativeTtsController(
    context: Context,
    private val onStarted: (requestId: String?) -> Unit,
    private val onCompleted: (requestId: String?, success: Boolean, error: String?) -> Unit,
    private val onInitDiagnostics: (Map<String, Any?>) -> Unit,
    private val isAsrActive: () -> Boolean,
    private val isAudioRecordActive: () -> Boolean,
) {
    private data class PendingPlay(
        val requestId: String?,
        val text: String,
        val speechRate: Double,
        val locale: String,
    )

    private data class InitAttemptSnapshot(
        val engineUsed: String,
        val systemEngineList: List<String>,
        val systemDefaultEngine: String?,
        val contextValid: Boolean,
        val isActivityContext: Boolean,
        val activityValid: Boolean,
        val onMainThread: Boolean,
        val asrActive: Boolean,
        val audioRecordActive: Boolean,
    )

    private val initContext = context
    private val initialized = AtomicBoolean(false)
    private val initFailed = AtomicBoolean(false)
    private val initInFlight = AtomicBoolean(false)
    private val ttsPlaying = AtomicBoolean(false)
    private val activeRequests = ConcurrentHashMap.newKeySet<String>()

    @Volatile
    private var lastUtteranceId: String? = null

    @Volatile
    private var pendingPlay: PendingPlay? = null

    @Volatile
    private var tts: TextToSpeech? = null

    @Volatile
    private var initAttemptSnapshot: InitAttemptSnapshot? = null

    init {
        createEngine()
    }

    private fun createEngine(enginePackage: String? = null) {
        if (!initInFlight.compareAndSet(false, true)) return
        initialized.set(false)
        val usedEngine = enginePackage ?: "default"
        initAttemptSnapshot = buildInitAttemptSnapshot(usedEngine)
        Log.i(TAG, "createEngine: init start engine=$usedEngine")
        tts = if (enginePackage == null) {
            TextToSpeech(initContext) { status ->
                onEngineInit(status, enginePackage)
            }
        } else {
            TextToSpeech(initContext, { status ->
                onEngineInit(status, enginePackage)
            }, enginePackage)
        }
    }

    private fun getSystemTtsEngineList(): List<String> {
        return runCatching {
            val intent = Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE)
            @Suppress("DEPRECATION")
            val list = initContext.packageManager.queryIntentServices(intent, 0)
            list.mapNotNull { it.serviceInfo?.packageName }.distinct()
        }.getOrDefault(emptyList())
    }

    private fun getSystemDefaultTtsEngine(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return null
        return runCatching {
            val method = TextToSpeech::class.java.getMethod("getDefaultEngine", Context::class.java)
            method.invoke(null, initContext) as? String
        }.getOrNull()
    }

    private fun buildInitAttemptSnapshot(usedEngine: String): InitAttemptSnapshot {
        val isActivityContext = initContext is Activity
        val activityValid = if (initContext is Activity) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
                !initContext.isFinishing && !initContext.isDestroyed
            } else {
                !initContext.isFinishing
            }
        } else {
            false
        }
        val contextValid = runCatching {
            initContext.packageName.isNotBlank()
        }.getOrDefault(false)
        return InitAttemptSnapshot(
            engineUsed = usedEngine,
            systemEngineList = getSystemTtsEngineList(),
            systemDefaultEngine = getSystemDefaultTtsEngine(),
            contextValid = contextValid,
            isActivityContext = isActivityContext,
            activityValid = activityValid,
            onMainThread = Looper.myLooper() == Looper.getMainLooper(),
            asrActive = isAsrActive(),
            audioRecordActive = isAudioRecordActive(),
        )
    }

    private fun onEngineInit(status: Int, enginePackage: String?) {
        initInFlight.set(false)
        val success = status == TextToSpeech.SUCCESS
        initialized.set(success)
        initFailed.set(!success)

        val snapshot = initAttemptSnapshot
        val usedEngine = enginePackage ?: snapshot?.engineUsed ?: "default"
        val engineList = snapshot?.systemEngineList ?: emptyList<String>()
        val defaultEngine = snapshot?.systemDefaultEngine

        val diagnostics = mapOf(
            "engineList" to engineList,
            "defaultEngine" to defaultEngine,
            "engineUsed" to usedEngine,
            "initStatus" to status,
            "initStatusName" to describeInitStatus(status),
            "initErrorCode" to if (success) null else status,
            "initSuccess" to success,
            "contextValid" to (snapshot?.contextValid ?: false),
            "isActivityContext" to (snapshot?.isActivityContext ?: false),
            "activityValid" to (snapshot?.activityValid ?: false),
            "onMainThread" to (snapshot?.onMainThread ?: false),
            "asrActive" to (snapshot?.asrActive ?: false),
            "audioRecordActive" to (snapshot?.audioRecordActive ?: false),
        )
        onInitDiagnostics(diagnostics)

        Log.i(
            TAG,
            "createEngine: init callback engine=$usedEngine status=$status(${describeInitStatus(status)}), success=$success",
        )

        if (success) {
            val localeResult = tts?.setLanguage(Locale.SIMPLIFIED_CHINESE)
            Log.i(
                TAG,
                "createEngine: setLanguage locale=zh-CN result=$localeResult(${describeLanguageResult(localeResult)})",
            )
            tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    ttsPlaying.set(true)
                    onStarted(utteranceId)
                }

                override fun onDone(utteranceId: String?) {
                    ttsPlaying.set(false)
                    val resolvedId = utteranceId ?: lastUtteranceId
                    if (resolvedId != null) activeRequests.remove(resolvedId)
                    if (resolvedId != null && resolvedId == lastUtteranceId) {
                        lastUtteranceId = null
                    }
                    onCompleted(resolvedId, true, null)
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    ttsPlaying.set(false)
                    val resolvedId = utteranceId ?: lastUtteranceId
                    if (resolvedId != null) activeRequests.remove(resolvedId)
                    if (resolvedId != null && resolvedId == lastUtteranceId) {
                        lastUtteranceId = null
                    }
                    onCompleted(resolvedId, false, "tts_error")
                }

                override fun onError(utteranceId: String?, errorCode: Int) {
                    ttsPlaying.set(false)
                    val resolvedId = utteranceId ?: lastUtteranceId
                    if (resolvedId != null) activeRequests.remove(resolvedId)
                    if (resolvedId != null && resolvedId == lastUtteranceId) {
                        lastUtteranceId = null
                    }
                    onCompleted(resolvedId, false, "tts_error_$errorCode")
                }
            })

            val pending = pendingPlay
            if (pending != null) {
                pendingPlay = null
                speakInternal(
                    requestId = pending.requestId,
                    text = pending.text,
                    speechRate = pending.speechRate,
                    locale = pending.locale,
                )
            }
            return
        }

        Log.w(
            TAG,
            "createEngine: init failed engine=$usedEngine status=$status(${describeInitStatus(status)}), reason=tts_engine_init_failed",
        )
        val pending = pendingPlay
        pendingPlay = null
        if (pending != null) {
            Log.w(
                TAG,
                "createEngine: flush pending requestId=${pending.requestId} with tts_not_ready",
            )
            onCompleted(pending.requestId, false, "tts_not_ready")
        }
    }

    fun play(requestId: String?, text: String, speechRate: Double, locale: String): Boolean {
        if (text.isBlank()) return false
        if (!initialized.get()) {
            if (!initInFlight.get() && initFailed.get()) {
                onCompleted(requestId, false, "tts_not_ready")
                return false
            }
            pendingPlay = PendingPlay(
                requestId = requestId,
                text = text,
                speechRate = speechRate,
                locale = locale,
            )
            Log.w(TAG, "play: engine not initialized, queued requestId=$requestId")
            return true
        }
        return speakInternal(requestId, text, speechRate, locale)
    }

    private fun speakInternal(
        requestId: String?,
        text: String,
        speechRate: Double,
        locale: String,
    ): Boolean {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()
        val engine = tts ?: return false
        engine.setAudioAttributes(attrs)
        engine.setSpeechRate(speechRate.toFloat())
        val localeResult = engine.setLanguage(Locale.forLanguageTag(locale))
        Log.i(
            TAG,
            "speakInternal: requestId=$requestId locale=$locale setLanguageResult=$localeResult(${describeLanguageResult(localeResult)})",
        )

        val utteranceId = requestId ?: "tts_${System.currentTimeMillis()}"
        lastUtteranceId = utteranceId
        activeRequests.add(utteranceId)
        val result = engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
        if (result != TextToSpeech.SUCCESS) {
            Log.e(
                TAG,
                "speakInternal: speak failed requestId=$requestId utteranceId=$utteranceId locale=$locale speechRate=$speechRate result=$result",
            )
            activeRequests.remove(utteranceId)
            if (utteranceId == lastUtteranceId) {
                lastUtteranceId = null
            }
        } else {
            Log.i(
                TAG,
                "speakInternal: speak success requestId=$requestId utteranceId=$utteranceId locale=$locale speechRate=$speechRate",
            )
        }
        return result == TextToSpeech.SUCCESS
    }

    private fun describeInitStatus(status: Int): String {
        return when (status) {
            TextToSpeech.SUCCESS -> "SUCCESS"
            TextToSpeech.ERROR -> "ERROR"
            else -> "UNKNOWN"
        }
    }

    private fun describeLanguageResult(result: Int?): String {
        if (result == null) return "ENGINE_NULL"
        return when (result) {
            TextToSpeech.LANG_AVAILABLE -> "LANG_AVAILABLE"
            TextToSpeech.LANG_COUNTRY_AVAILABLE -> "LANG_COUNTRY_AVAILABLE"
            TextToSpeech.LANG_COUNTRY_VAR_AVAILABLE -> "LANG_COUNTRY_VAR_AVAILABLE"
            TextToSpeech.LANG_MISSING_DATA -> "LANG_MISSING_DATA"
            TextToSpeech.LANG_NOT_SUPPORTED -> "LANG_NOT_SUPPORTED"
            TextToSpeech.ERROR -> "ERROR"
            else -> "UNKNOWN"
        }
    }

    fun stop(reason: String = "manual_stop"): Boolean {
        val queued = pendingPlay
        if (queued != null) {
            pendingPlay = null
            onCompleted(queued.requestId, true, reason)
        }
        if (!initialized.get()) return false
        val result = tts?.stop() == TextToSpeech.SUCCESS
        ttsPlaying.set(false)
        val activePending = activeRequests.toList()
        activeRequests.clear()
        lastUtteranceId = null
        activePending.forEach { onCompleted(it, true, reason) }
        return result
    }

    fun isPlaying(): Boolean = ttsPlaying.get()

    fun release() {
        try {
            tts?.stop()
        } catch (_: Throwable) {
        }
        try {
            tts?.shutdown()
        } catch (_: Throwable) {
        }
        tts = null
        initialized.set(false)
        initFailed.set(false)
        initInFlight.set(false)
        ttsPlaying.set(false)
        pendingPlay = null
        lastUtteranceId = null
        activeRequests.clear()
        initAttemptSnapshot = null
    }

    companion object {
        private const val TAG = "NativeTtsController"
    }
}
