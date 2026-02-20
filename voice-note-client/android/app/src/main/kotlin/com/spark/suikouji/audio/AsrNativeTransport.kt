package com.spark.suikouji.audio

import android.util.Base64
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean

class AsrNativeTransport(
    private val onInterimText: (String) -> Unit,
    private val onFinalText: (String) -> Unit,
    private val onError: (String) -> Unit,
) {
    private val client = OkHttpClient()
    private var socket: WebSocket? = null
    private val connected = AtomicBoolean(false)

    fun connect(token: String, wsUrl: String, model: String) {
        disconnect()
        val url = "$wsUrl?model=$model"
        val request = Request.Builder()
            .url(url)
            .addHeader("Authorization", "Bearer $token")
            .addHeader("OpenAI-Beta", "realtime=v1")
            .build()
        socket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                connected.set(true)
                webSocket.send(buildSessionUpdate().toString())
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                try {
                    handleMessage(text)
                } catch (t: Throwable) {
                    onError("asr_parse_error:${t.message}")
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                connected.set(false)
                onError("asr_ws_failure:${t.message}")
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                connected.set(false)
            }
        })
    }

    fun sendAudioFrame(frame: ByteArray) {
        if (!connected.get()) return
        val payload = JSONObject()
            .put("event_id", "evt_${System.currentTimeMillis()}")
            .put("type", "input_audio_buffer.append")
            .put("audio", Base64.encodeToString(frame, Base64.NO_WRAP))
        socket?.send(payload.toString())
    }

    fun commit() {
        if (!connected.get()) return
        val payload = JSONObject()
            .put("event_id", "evt_commit_${System.currentTimeMillis()}")
            .put("type", "input_audio_buffer.commit")
        socket?.send(payload.toString())
    }

    fun disconnect() {
        connected.set(false)
        socket?.close(1000, "client_close")
        socket = null
    }

    fun isConnected(): Boolean = connected.get()

    private fun buildSessionUpdate(): JSONObject {
        val session = JSONObject()
            .put("modalities", JSONArray().put("text"))
            .put("input_audio_format", "pcm")
            .put("sample_rate", 16000)
            .put("input_audio_transcription", JSONObject().put("language", "zh"))
            // Server VAD lets native runtime stream continuously without Flutter VAD.
            .put("turn_detection", JSONObject().put("type", "server_vad"))
        return JSONObject()
            .put("event_id", "evt_session_update_${System.currentTimeMillis()}")
            .put("type", "session.update")
            .put("session", session)
    }

    private fun handleMessage(raw: String) {
        val data = JSONObject(raw)
        when (data.optString("type")) {
            "conversation.item.input_audio_transcription.text",
            "response.audio_transcript.delta" -> {
                val text = data.optString("text", data.optString("delta", ""))
                if (text.isNotBlank()) onInterimText(text)
            }
            "conversation.item.input_audio_transcription.completed",
            "response.audio_transcript.done" -> {
                val text = data.optString("transcript", "")
                if (text.isNotBlank()) onFinalText(text)
            }
            "conversation.item.created" -> {
                val item = data.optJSONObject("item") ?: return
                val content = item.optJSONArray("content") ?: return
                for (i in 0 until content.length()) {
                    val part = content.optJSONObject(i) ?: continue
                    val text = part.optString("transcript", part.optString("text", ""))
                    if (text.isNotBlank()) {
                        onFinalText(text)
                        return
                    }
                }
            }
            "error" -> {
                val error = data.optJSONObject("error")
                onError(error?.optString("message", "unknown_asr_error") ?: "unknown_asr_error")
            }
        }
    }
}
