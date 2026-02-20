package com.spark.suikouji.audio

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class NativeAudioPlugin : MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private lateinit var runtimeController: AudioRuntimeController

    fun attach(context: Context, methodChannel: MethodChannel, eventChannel: EventChannel) {
        this.methodChannel = methodChannel
        this.eventChannel = eventChannel
        this.runtimeController = AudioRuntimeController(context) { event, payload ->
            val sink = eventSink ?: return@AudioRuntimeController
            val envelope = mutableMapOf<String, Any?>(
                "event" to event,
                "sessionId" to (payload["sessionId"] as? String ?: ""),
                "requestId" to payload["requestId"],
                "timestamp" to (payload["timestamp"] as? Long ?: System.currentTimeMillis()),
                "data" to (payload["data"] ?: emptyMap<String, Any?>()),
                "error" to payload["error"],
            )
            mainHandler.post { sink.success(envelope) }
        }
        this.methodChannel.setMethodCallHandler(this)
        this.eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val args = (call.arguments as? Map<*, *>)?.entries
            ?.associate { it.key.toString() to it.value } ?: emptyMap<String, Any?>()

        val output = when (call.method) {
            "initializeSession" -> runtimeController.initializeSession(args)
            "disposeSession" -> runtimeController.disposeSession(args)
            "setAsrMuted" -> runtimeController.setAsrMuted(args)
            "playTts" -> runtimeController.playTts(args)
            "stopTts" -> runtimeController.stopTts(args)
            "setBargeInConfig" -> runtimeController.setBargeInConfig(args)
            "getDuplexStatus" -> runtimeController.getDuplexStatus()
            "switchInputMode" -> runtimeController.switchInputMode(args)
            "getLifecycleSnapshot" -> runtimeController.getLifecycleSnapshot()
            "restoreLifecycleSnapshot" -> runtimeController.restoreLifecycleSnapshot(args)
            "startAsrStream" -> runtimeController.startAsrStream(args)
            "commitAsr" -> runtimeController.commitAsr()
            "stopAsrStream" -> runtimeController.stopAsrStream()
            "startCapture" -> runtimeController.startCapture(args)
            "stopCapture" -> runtimeController.stopCapture(args)
            else -> null
        }

        if (output != null) {
            result.success(output)
        } else {
            result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
