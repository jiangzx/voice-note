package com.suikouji.server.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "rate-limit")
data class RateLimitProperties(
    val asr: Bucket = Bucket(tokensPerMinute = 30),
    val llm: Bucket = Bucket(tokensPerMinute = 60),
    val trustedProxies: List<String> = emptyList()
) {
    data class Bucket(
        val tokensPerMinute: Long = 60,
        val burstCapacity: Long = tokensPerMinute
    )
}
