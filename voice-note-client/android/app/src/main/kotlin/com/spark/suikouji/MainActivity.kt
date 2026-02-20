package com.spark.suikouji

import com.spark.suikouji.audio.NativeAudioPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val nativeAudioPlugin = NativeAudioPlugin()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeAudioPlugin.attach(
            context = this,
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "voice_note/native_audio"),
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, "voice_note/native_audio/events"),
        )
    }
}
