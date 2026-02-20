package com.spark.suikouji.audio

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class AsrCaptureRuntime(
    private val sampleRate: Int = 16_000,
    private val onAudioFrame: (ByteArray) -> Unit,
) {
    // Capture thread runs for the whole session; gate controls ASR forwarding.
    private val running = AtomicBoolean(false)
    @Volatile private var asrMuted: Boolean = false
    private var recordThread: Thread? = null
    private var audioRecord: AudioRecord? = null

    fun start() {
        if (!running.compareAndSet(false, true)) return

        val minBuffer = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        ).coerceAtLeast(3200)

        val recorder = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBuffer,
        )
        audioRecord = recorder
        recorder.startRecording()

        recordThread = thread(
            name = "native-asr-capture",
            start = true,
        ) {
            val buffer = ByteArray(3200)
            while (running.get()) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read <= 0) continue
                val frame = buffer.copyOf(read)
                if (!asrMuted) {
                    onAudioFrame(frame)
                } else {
                    // Keep frames flowing for local detectors (e.g., barge-in),
                    // while higher layer decides whether to forward to ASR.
                    onAudioFrame(frame)
                }
            }
        }
    }

    fun setAsrMuted(muted: Boolean) {
        asrMuted = muted
    }

    fun isAsrMuted(): Boolean = asrMuted

    fun isRunning(): Boolean = running.get()

    fun stop() {
        if (!running.compareAndSet(true, false)) return
        try {
            audioRecord?.stop()
        } catch (_: Throwable) {
        }
        try {
            audioRecord?.release()
        } catch (_: Throwable) {
        }
        audioRecord = null
        recordThread = null
    }
}
