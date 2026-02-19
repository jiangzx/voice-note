package com.suikouji.server.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "dashscope")
data class DashScopeProperties(
    val apiKey: String,
    val baseUrl: String = "https://dashscope.aliyuncs.com",
    val asr: Asr = Asr(),
    val llm: Llm = Llm()
) {
    data class Asr(
        val tokenTtlSeconds: Int = 300,
        val model: String = "qwen3-asr-flash-realtime",
        val wsEndpoint: String = "/api-ws/v1/realtime"
    )

    data class Llm(
        val primaryModel: String = "qwen-turbo",
        val fallbackModel: String = "qwen-plus",
        val maxTokens: Int = 500,
        val temperature: Double = 0.1
    )
}
