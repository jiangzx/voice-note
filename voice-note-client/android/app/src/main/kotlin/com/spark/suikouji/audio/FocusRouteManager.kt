package com.spark.suikouji.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build

class FocusRouteManager(
    context: Context,
    private val onFocusChanged: (focusState: String, canAutoResume: Boolean) -> Unit,
) {
    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private var currentFocusState: String = "idle"
    private var focusRequest: AudioFocusRequest? = null

    fun requestPlaybackFocus() {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ASSISTANT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
            .build()

        val listener = AudioManager.OnAudioFocusChangeListener { change ->
            when (change) {
                AudioManager.AUDIOFOCUS_GAIN -> {
                    currentFocusState = "gain"
                    onFocusChanged("gain", true)
                }
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK,
                -> {
                    currentFocusState = "loss_transient"
                    onFocusChanged("loss_transient", true)
                }
                AudioManager.AUDIOFOCUS_LOSS -> {
                    // Permanent loss should not auto-resume.
                    currentFocusState = "loss"
                    onFocusChanged("loss", false)
                }
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(attrs)
                .setOnAudioFocusChangeListener(listener)
                .build()
            focusRequest = req
            audioManager.requestAudioFocus(req)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                listener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            )
        }
        currentFocusState = "gain"
        onFocusChanged("gain", true)
    }

    fun abandonPlaybackFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val req = focusRequest
            if (req != null) {
                audioManager.abandonAudioFocusRequest(req)
            }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
        currentFocusState = "idle"
        onFocusChanged("idle", true)
    }

    fun getFocusState(): String = currentFocusState

    fun getRoute(): String {
        // Route is normalized to keep Flutter payload stable across Android APIs.
        return when {
            audioManager.isBluetoothScoOn -> "bluetooth"
            audioManager.isSpeakerphoneOn -> "speaker"
            else -> "earpiece"
        }
    }
}
