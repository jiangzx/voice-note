package com.suikouji.server.config

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.MDC
import org.springframework.core.Ordered
import org.springframework.core.annotation.Order
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter
import java.util.UUID

/**
 * Assigns a correlation ID to every request and places it in MDC
 * for structured log tracing. Respects incoming X-Request-ID if present.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
class CorrelationIdFilter : OncePerRequestFilter() {

    companion object {
        const val HEADER_NAME = "X-Request-ID"
        const val SESSION_HEADER = "X-Session-Id"
        const val MDC_KEY = "requestId"
        const val SESSION_MDC_KEY = "sessionId"
        private const val MAX_LENGTH = 64
        private val SAFE_PATTERN = Regex("[^a-zA-Z0-9\\-_.]")

        fun sanitizeRequestId(raw: String): String =
            SAFE_PATTERN.replace(raw, "").take(MAX_LENGTH)
    }

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val requestId = request.getHeader(HEADER_NAME)
            ?.takeIf { it.isNotBlank() }
            ?.let { sanitizeRequestId(it) }
            ?.takeIf { it.isNotEmpty() }
            ?: UUID.randomUUID().toString().substring(0, 8)

        val sessionId = request.getHeader(SESSION_HEADER)
            ?.takeIf { it.isNotBlank() }
            ?.let { sanitizeRequestId(it) }

        MDC.put(MDC_KEY, requestId)
        if (sessionId != null) MDC.put(SESSION_MDC_KEY, sessionId)
        response.setHeader(HEADER_NAME, requestId)
        try {
            filterChain.doFilter(request, response)
        } finally {
            MDC.remove(MDC_KEY)
            MDC.remove(SESSION_MDC_KEY)
        }
    }
}
