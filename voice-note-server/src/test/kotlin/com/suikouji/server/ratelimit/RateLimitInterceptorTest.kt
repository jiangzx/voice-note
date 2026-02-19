package com.suikouji.server.ratelimit

import com.suikouji.server.config.RateLimitProperties
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.io.PrintWriter
import java.io.StringWriter
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class RateLimitInterceptorTest {

    private lateinit var interceptor: RateLimitInterceptor

    @BeforeEach
    fun setup() {
        interceptor = RateLimitInterceptor(
            RateLimitProperties(
                asr = RateLimitProperties.Bucket(tokensPerMinute = 2, burstCapacity = 2),
                llm = RateLimitProperties.Bucket(tokensPerMinute = 3, burstCapacity = 3)
            )
        )
    }

    private fun mockRequest(path: String, ip: String = "127.0.0.1"): HttpServletRequest {
        val req = mockk<HttpServletRequest>()
        every { req.requestURI } returns path
        every { req.remoteAddr } returns ip
        every { req.getHeader("X-Forwarded-For") } returns null
        every { req.getHeader("X-Real-IP") } returns null
        return req
    }

    private fun mockResponse(): Pair<HttpServletResponse, StringWriter> {
        val res = mockk<HttpServletResponse>(relaxed = true)
        val writer = StringWriter()
        every { res.writer } returns PrintWriter(writer)
        return res to writer
    }

    @Test
    fun `allows requests within ASR rate limit`() {
        val req = mockRequest("/api/v1/asr/token")
        val (res, _) = mockResponse()

        assertTrue(interceptor.preHandle(req, res, Any()))
        assertTrue(interceptor.preHandle(req, res, Any()))
    }

    @Test
    fun `rejects ASR request exceeding limit with 429`() {
        val req = mockRequest("/api/v1/asr/token")
        val (res, _) = mockResponse()

        // Exhaust the 2-token burst
        interceptor.preHandle(req, res, Any())
        interceptor.preHandle(req, res, Any())

        // Third request should be rejected
        val result = interceptor.preHandle(req, res, Any())
        assertFalse(result)
        verify { res.status = 429 }
    }

    @Test
    fun `allows LLM requests within separate limit`() {
        val req = mockRequest("/api/v1/llm/parse-transaction")
        val (res, _) = mockResponse()

        assertTrue(interceptor.preHandle(req, res, Any()))
        assertTrue(interceptor.preHandle(req, res, Any()))
        assertTrue(interceptor.preHandle(req, res, Any()))
    }

    @Test
    fun `ASR and LLM have independent limits`() {
        val asrReq = mockRequest("/api/v1/asr/token")
        val llmReq = mockRequest("/api/v1/llm/parse-transaction")
        val (res, _) = mockResponse()

        // Exhaust ASR limit
        interceptor.preHandle(asrReq, res, Any())
        interceptor.preHandle(asrReq, res, Any())
        assertFalse(interceptor.preHandle(asrReq, res, Any()))

        // LLM should still work
        assertTrue(interceptor.preHandle(llmReq, res, Any()))
    }

    @Test
    fun `different IPs have independent limits`() {
        val req1 = mockRequest("/api/v1/asr/token", ip = "10.0.0.1")
        val req2 = mockRequest("/api/v1/asr/token", ip = "10.0.0.2")
        val (res, _) = mockResponse()

        // Exhaust IP1's limit
        interceptor.preHandle(req1, res, Any())
        interceptor.preHandle(req1, res, Any())
        assertFalse(interceptor.preHandle(req1, res, Any()))

        // IP2 should still work
        assertTrue(interceptor.preHandle(req2, res, Any()))
    }

    @Test
    fun `non-API paths are not rate limited`() {
        val req = mockRequest("/actuator/health")
        val (res, _) = mockResponse()

        // Should always pass
        for (i in 1..10) {
            assertTrue(interceptor.preHandle(req, res, Any()))
        }
    }

    @Test
    fun `429 response body contains error JSON`() {
        val req = mockRequest("/api/v1/asr/token")
        val (res, writer) = mockResponse()

        interceptor.preHandle(req, res, Any())
        interceptor.preHandle(req, res, Any())
        interceptor.preHandle(req, res, Any())

        val body = writer.toString()
        assertTrue(body.contains("rate_limit_exceeded"))
    }

    @Test
    fun `429 response sets content type with charset`() {
        val req = mockRequest("/api/v1/asr/token")
        val (res, _) = mockResponse()

        interceptor.preHandle(req, res, Any())
        interceptor.preHandle(req, res, Any())
        interceptor.preHandle(req, res, Any())

        verify { res.contentType = "application/json;charset=UTF-8" }
    }

    @Test
    fun `uses X-Forwarded-For when request comes from trusted proxy`() {
        val proxyInterceptor = RateLimitInterceptor(
            RateLimitProperties(
                asr = RateLimitProperties.Bucket(tokensPerMinute = 1, burstCapacity = 1),
                llm = RateLimitProperties.Bucket(tokensPerMinute = 10, burstCapacity = 10),
                trustedProxies = listOf("10.0.0.1")
            )
        )

        val req1 = mockk<HttpServletRequest>()
        every { req1.requestURI } returns "/api/v1/asr/token"
        every { req1.remoteAddr } returns "10.0.0.1"
        every { req1.getHeader("X-Forwarded-For") } returns "192.168.1.100"
        every { req1.getHeader("X-Real-IP") } returns null

        val req2 = mockk<HttpServletRequest>()
        every { req2.requestURI } returns "/api/v1/asr/token"
        every { req2.remoteAddr } returns "10.0.0.1"
        every { req2.getHeader("X-Forwarded-For") } returns "192.168.1.200"
        every { req2.getHeader("X-Real-IP") } returns null

        val (res, _) = mockResponse()

        assertTrue(proxyInterceptor.preHandle(req1, res, Any()))
        assertTrue(proxyInterceptor.preHandle(req2, res, Any()))
    }

    @Test
    fun `uses leftmost client IP from X-Forwarded-For`() {
        val proxyInterceptor = RateLimitInterceptor(
            RateLimitProperties(
                asr = RateLimitProperties.Bucket(tokensPerMinute = 1, burstCapacity = 1),
                llm = RateLimitProperties.Bucket(tokensPerMinute = 10, burstCapacity = 10),
                trustedProxies = listOf("10.0.0.1")
            )
        )

        val req1 = mockk<HttpServletRequest>()
        every { req1.requestURI } returns "/api/v1/asr/token"
        every { req1.remoteAddr } returns "10.0.0.1"
        every { req1.getHeader("X-Forwarded-For") } returns "192.168.1.100, 5.5.5.5"
        every { req1.getHeader("X-Real-IP") } returns null

        val req2 = mockk<HttpServletRequest>()
        every { req2.requestURI } returns "/api/v1/asr/token"
        every { req2.remoteAddr } returns "10.0.0.1"
        every { req2.getHeader("X-Forwarded-For") } returns "192.168.1.100"
        every { req2.getHeader("X-Real-IP") } returns null

        val (res, _) = mockResponse()

        assertTrue(proxyInterceptor.preHandle(req1, res, Any()))
        // Same real client — leftmost IP 192.168.1.100 should share the bucket
        assertFalse(proxyInterceptor.preHandle(req2, res, Any()))
    }

    @Test
    fun `falls back to direct IP on malformed X-Forwarded-For with trailing comma`() {
        val proxyInterceptor = RateLimitInterceptor(
            RateLimitProperties(
                asr = RateLimitProperties.Bucket(tokensPerMinute = 1, burstCapacity = 1),
                llm = RateLimitProperties.Bucket(tokensPerMinute = 10, burstCapacity = 10),
                trustedProxies = listOf("10.0.0.1")
            )
        )

        val req = mockk<HttpServletRequest>()
        every { req.requestURI } returns "/api/v1/asr/token"
        every { req.remoteAddr } returns "10.0.0.1"
        every { req.getHeader("X-Forwarded-For") } returns "192.168.1.100,"
        every { req.getHeader("X-Real-IP") } returns null

        val (res, _) = mockResponse()

        assertTrue(proxyInterceptor.preHandle(req, res, Any()))
        // Malformed XFF trailing comma → last segment is empty → falls back to directIp
        assertFalse(proxyInterceptor.preHandle(req, res, Any()))
    }

    @Test
    fun `uses X-Real-IP when X-Forwarded-For is absent and proxy is trusted`() {
        val proxyInterceptor = RateLimitInterceptor(
            RateLimitProperties(
                asr = RateLimitProperties.Bucket(tokensPerMinute = 1, burstCapacity = 1),
                llm = RateLimitProperties.Bucket(tokensPerMinute = 10, burstCapacity = 10),
                trustedProxies = listOf("10.0.0.1")
            )
        )

        val req = mockk<HttpServletRequest>()
        every { req.requestURI } returns "/api/v1/asr/token"
        every { req.remoteAddr } returns "10.0.0.1"
        every { req.getHeader("X-Forwarded-For") } returns null
        every { req.getHeader("X-Real-IP") } returns "172.16.0.50"

        val (res, _) = mockResponse()

        assertTrue(proxyInterceptor.preHandle(req, res, Any()))
        // Exhaust the limit for 172.16.0.50
        assertFalse(proxyInterceptor.preHandle(req, res, Any()))
    }

    @Test
    fun `ignores forwarded headers from untrusted proxy`() {
        val req = mockk<HttpServletRequest>()
        every { req.requestURI } returns "/api/v1/asr/token"
        every { req.remoteAddr } returns "1.2.3.4"
        every { req.getHeader("X-Forwarded-For") } returns "5.6.7.8"
        every { req.getHeader("X-Real-IP") } returns "5.6.7.8"

        val (res, _) = mockResponse()

        assertTrue(interceptor.preHandle(req, res, Any()))
        assertTrue(interceptor.preHandle(req, res, Any()))
        // 1.2.3.4 limit exhausted (not 5.6.7.8)
        assertFalse(interceptor.preHandle(req, res, Any()))
    }
}
