package com.suikouji.server.ratelimit

import com.github.benmanes.caffeine.cache.Caffeine
import com.suikouji.server.config.RateLimitProperties
import io.github.bucket4j.Bandwidth
import io.github.bucket4j.Bucket
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.servlet.HandlerInterceptor
import java.time.Duration

/**
 * IP-based rate limiter using token-bucket algorithm.
 * Buckets are bounded by Caffeine cache (max 10k entries, 10min TTL)
 * to prevent unbounded memory growth from diverse client IPs.
 */
@Component
class RateLimitInterceptor(
    private val properties: RateLimitProperties
) : HandlerInterceptor {

    private val log = LoggerFactory.getLogger(javaClass)

    private val buckets = Caffeine.newBuilder()
        .maximumSize(10_000)
        .expireAfterAccess(Duration.ofMinutes(10))
        .build<String, Bucket>()

    override fun preHandle(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any
    ): Boolean {
        val clientIp = resolveClientIp(request)
        val path = request.requestURI
        val bucketConfig = resolveBucketConfig(path) ?: return true

        val key = "$clientIp:${bucketConfig.first}"
        val bucket = buckets.get(key) { createBucket(bucketConfig.second) }

        if (!bucket.tryConsume(1)) {
            log.warn("Rate limit exceeded: clientIp={}, path={}, bucket={}", clientIp, path, bucketConfig.first)
            response.status = HttpStatus.TOO_MANY_REQUESTS.value()
            response.contentType = "application/json;charset=UTF-8"
            response.writer.write("""{"error":"rate_limit_exceeded","message":"Too many requests. Please try again later."}""")
            return false
        }
        return true
    }

    /**
     * Resolve real client IP behind reverse proxy.
     * Only trusts X-Forwarded-For / X-Real-IP when the direct
     * connection comes from a configured trusted proxy.
     */
    private fun resolveClientIp(request: HttpServletRequest): String {
        val directIp = request.remoteAddr
        if (!isTrustedProxy(directIp)) return directIp

        val forwarded = request.getHeader("X-Forwarded-For")
        if (!forwarded.isNullOrBlank()) {
            // X-Forwarded-For is "client, proxy1, proxy2"; client is left-most.
            val clientIp = forwarded.split(",").first().trim()
            if (clientIp.isNotBlank()) return clientIp
        }
        val realIp = request.getHeader("X-Real-IP")
        if (!realIp.isNullOrBlank()) {
            return realIp.trim()
        }
        return directIp
    }

    private fun isTrustedProxy(ip: String): Boolean =
        properties.trustedProxies.any { it == ip }

    private fun resolveBucketConfig(path: String): Pair<String, RateLimitProperties.Bucket>? = when {
        path.startsWith("/api/v1/asr") -> "asr" to properties.asr
        path.startsWith("/api/v1/llm") -> "llm" to properties.llm
        else -> null
    }

    private fun createBucket(config: RateLimitProperties.Bucket): Bucket {
        val limit = Bandwidth.builder()
            .capacity(config.burstCapacity)
            .refillGreedy(config.tokensPerMinute, Duration.ofMinutes(1))
            .build()
        return Bucket.builder().addLimit(limit).build()
    }
}
