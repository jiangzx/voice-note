package com.suikouji.server.asr

import com.fasterxml.jackson.annotation.JsonProperty
import com.suikouji.server.config.DashScopeProperties
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.web.reactive.function.client.WebClient
import org.springframework.web.reactive.function.client.awaitBody

@Service
class AsrTokenService(
    private val dashScopeWebClient: WebClient,
    private val properties: DashScopeProperties
) {
    private val log = LoggerFactory.getLogger(javaClass)

    @Volatile
    private var cached: CachedToken? = null

    fun evictCache() {
        cached = null
    }

    suspend fun generateTemporaryToken(): AsrTokenResponse {
        cached?.let { (token, expiry) ->
            if (System.currentTimeMillis() < expiry) {
                log.debug("Returning cached ASR token")
                return token
            }
        }
        return fetchAndCache()
    }

    private suspend fun fetchAndCache(): AsrTokenResponse {
        val ttl = properties.asr.tokenTtlSeconds
        log.debug("Fetching ASR token from DashScope with TTL={}s", ttl)

        val startMs = System.currentTimeMillis()
        val response = dashScopeWebClient
            .post()
            .uri("/api/v1/tokens?expire_in_seconds={ttl}", ttl)
            .retrieve()
            .awaitBody<DashScopeTokenResponse>()
        val durationMs = System.currentTimeMillis() - startMs

        log.info("ASR token generated: model={}, durationMs={}", properties.asr.model, durationMs)

        val token = AsrTokenResponse(
            token = response.token,
            expiresAt = response.expiresAt,
            model = properties.asr.model,
            wsUrl = toWsUrl(properties.baseUrl, properties.asr.wsEndpoint)
        )

        val bufferMs = maxOf((ttl - 30L) * 1000, 10_000)
        cached = CachedToken(token, System.currentTimeMillis() + bufferMs)
        return token
    }

    private fun toWsUrl(baseUrl: String, endpoint: String): String {
        val wsBase = baseUrl
            .replaceFirst("https://", "wss://")
            .replaceFirst("http://", "ws://")
        return "$wsBase$endpoint"
    }

    private data class CachedToken(val token: AsrTokenResponse, val expiresAtMs: Long)
}

/** DashScope token API response. */
internal data class DashScopeTokenResponse(
    val token: String,
    @JsonProperty("expires_at") val expiresAt: Long
)
