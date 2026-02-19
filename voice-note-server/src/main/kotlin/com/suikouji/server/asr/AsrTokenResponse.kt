package com.suikouji.server.asr

/** Response returned to client with a temporary ASR credential. */
data class AsrTokenResponse(
    val token: String,
    val expiresAt: Long,
    val model: String,
    val wsUrl: String
)
