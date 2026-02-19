package com.suikouji.server.config

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.servlet.HandlerInterceptor
import java.security.MessageDigest

/**
 * Validates X-API-Key header on protected endpoints.
 * Disabled by default; enable via api-auth.enabled=true.
 * Uses constant-time comparison to prevent timing attacks.
 */
@Component
class ApiKeyInterceptor(
    private val properties: ApiKeyProperties
) : HandlerInterceptor {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun preHandle(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any
    ): Boolean {
        if (!properties.enabled) return true

        val provided = request.getHeader(HEADER_NAME)
        if (provided.isNullOrBlank() || !constantTimeEquals(provided, properties.key)) {
            log.warn("Rejected request from {} - invalid API key", request.remoteAddr)
            response.status = HttpStatus.UNAUTHORIZED.value()
            response.contentType = "application/json;charset=UTF-8"
            response.writer.write("""{"error":"unauthorized","message":"Invalid or missing API key"}""")
            return false
        }
        return true
    }

    /** Constant-time string comparison to prevent timing attacks. */
    private fun constantTimeEquals(a: String, b: String): Boolean =
        MessageDigest.isEqual(
            a.toByteArray(Charsets.UTF_8),
            b.toByteArray(Charsets.UTF_8)
        )

    companion object {
        const val HEADER_NAME = "X-API-Key"
    }
}
