package com.spark.suikouji.audio

import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import androidx.core.content.ContextCompat
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

class AsrCaptureRuntime(
    private val context: Context? = null,
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

        // Check permission before creating AudioRecord
        if (context != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val hasPermission = ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.RECORD_AUDIO
            ) == PackageManager.PERMISSION_GRANTED
            if (!hasPermission) {
                running.set(false)
                throw IllegalStateException("RECORD_AUDIO permission not granted")
            }
        }

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
        
        // Check AudioRecord state before starting
        if (recorder.state != AudioRecord.STATE_INITIALIZED) {
            recorder.release()
            running.set(false)
            val errorMsg = if (recorder.state == AudioRecord.STATE_UNINITIALIZED) {
                "AudioRecord initialization failed: permission may be denied or audio resource unavailable (state=0)"
            } else {
                "AudioRecord initialization failed: state=${recorder.state}"
            }
            throw IllegalStateException(errorMsg)
        }
        
        audioRecord = recorder
        try {
            recorder.startRecording()
        } catch (e: IllegalStateException) {
            recorder.release()
            audioRecord = null
            running.set(false)
            throw IllegalStateException("Failed to start AudioRecord: ${e.message}", e)
        }

        recordThread = thread(
            name = "native-asr-capture",
            start = true,
        ) {
            val buffer = ByteArray(3200)
            while (running.get()) {
                val read = recorder.read(buffer, 0, buffer.size)
                if (read <= 0) continue
                val frame = buffer.copyOf(read)
                // Always forward; AudioRuntimeController gates ASR by asrMuted and still needs frames for barge-in.
                onAudioFrame(frame)
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
