package com.spark.suikouji.audio

import kotlin.math.sqrt

data class BargeInConfig(
    val enabled: Boolean = true,
    val energyThreshold: Double = 0.5,
    val minSpeechMs: Int = 120,
    val cooldownMs: Int = 300,
)

class BargeInDetector(
    private val sampleRate: Int = 16_000,
    private val onTriggered: () -> Unit,
) {
    // Simple energy-based detector with hold-time + cooldown guards.
    @Volatile private var config: BargeInConfig = BargeInConfig()
    @Volatile private var speechMs: Int = 0
    @Volatile private var lastTriggerTs: Long = 0L

    fun updateConfig(newConfig: BargeInConfig) {
        config = newConfig
        speechMs = 0
    }

    fun onFrame(frame: ByteArray, ttsPlaying: Boolean) {
        val cfg = config
        if (!cfg.enabled || !ttsPlaying) {
            speechMs = 0
            return
        }

        val now = System.currentTimeMillis()
        if (now - lastTriggerTs < cfg.cooldownMs) return

        val rms = normalizedRms(frame)
        if (rms >= cfg.energyThreshold) {
            // Require continuous speech window to reduce accidental triggers.
            val frameMs = (frame.size / 2.0 / sampleRate * 1000).toInt().coerceAtLeast(1)
            speechMs += frameMs
            if (speechMs >= cfg.minSpeechMs) {
                lastTriggerTs = now
                speechMs = 0
                onTriggered()
            }
        } else {
            speechMs = 0
        }
    }

    private fun normalizedRms(frame: ByteArray): Double {
        if (frame.size < 2) return 0.0
        var sum = 0.0
        var count = 0
        var i = 0
        while (i + 1 < frame.size) {
            val sample = ((frame[i + 1].toInt() shl 8) or (frame[i].toInt() and 0xFF)).toShort()
            val n = sample.toDouble() / Short.MAX_VALUE.toDouble()
            sum += n * n
            count++
            i += 2
        }
        if (count == 0) return 0.0
        return sqrt(sum / count)
    }
}
