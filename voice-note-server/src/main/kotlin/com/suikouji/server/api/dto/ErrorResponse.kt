package com.suikouji.server.api.dto

import java.time.Instant

data class ErrorResponse(
    val error: String,
    val message: String,
    val timestamp: Instant = Instant.now()
)
