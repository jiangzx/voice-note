package com.spark.suikouji.audio

data class NormalizedError(
    val code: String,
    val message: String,
    val rawCode: String,
)

object ErrorMapper {
    fun normalize(rawCode: String?, fallbackMessage: String): NormalizedError {
        val safeRawCode = rawCode?.takeIf { it.isNotBlank() } ?: "unknown_error"
        val code = when {
            safeRawCode == "missing_session_id" || safeRawCode == "missing_snapshot" -> "invalid_argument"
            safeRawCode == "not_initialized" -> "not_initialized"
            safeRawCode.endsWith("_init_failed") -> "init_failed"
            safeRawCode == "tts_not_ready" -> "tts_unavailable"
            safeRawCode.startsWith("tts_error") -> "tts_failed"
            else -> "internal_error"
        }
        return NormalizedError(
            code = code,
            message = fallbackMessage,
            rawCode = safeRawCode,
        )
    }
}
