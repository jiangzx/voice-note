package com.suikouji.server.config

import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.junit.jupiter.api.Test
import org.slf4j.MDC
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class CorrelationIdFilterTest {

    private val filter = CorrelationIdFilter()

    private fun mockRequest(requestId: String? = null, sessionId: String? = null): HttpServletRequest {
        val req = mockk<HttpServletRequest>()
        every { req.getHeader(CorrelationIdFilter.HEADER_NAME) } returns requestId
        every { req.getHeader(CorrelationIdFilter.SESSION_HEADER) } returns sessionId
        every { req.requestURI } returns "/api/v1/test"
        every { req.servletPath } returns "/api/v1/test"
        every { req.getAttribute(any()) } returns null
        every { req.setAttribute(any(), any()) } returns Unit
        every { req.removeAttribute(any()) } returns Unit
        every { req.dispatcherType } returns jakarta.servlet.DispatcherType.REQUEST
        return req
    }

    private fun mockResponse(): HttpServletResponse {
        val res = mockk<HttpServletResponse>(relaxed = true)
        return res
    }

    @Test
    fun `generates requestId when none provided`() {
        val req = mockRequest()
        val res = mockResponse()
        var capturedId: String? = null

        val chain = FilterChain { _, _ -> capturedId = MDC.get(CorrelationIdFilter.MDC_KEY) }
        filter.doFilter(req, res, chain)

        assertNotNull(capturedId)
        assertEquals(8, capturedId!!.length)
        verify { res.setHeader(CorrelationIdFilter.HEADER_NAME, capturedId!!) }
    }

    @Test
    fun `reuses incoming X-Request-ID header`() {
        val req = mockRequest(requestId = "abc12345")
        val res = mockResponse()
        var capturedId: String? = null

        val chain = FilterChain { _, _ -> capturedId = MDC.get(CorrelationIdFilter.MDC_KEY) }
        filter.doFilter(req, res, chain)

        assertEquals("abc12345", capturedId)
        verify { res.setHeader(CorrelationIdFilter.HEADER_NAME, "abc12345") }
    }

    @Test
    fun `cleans MDC after request completes`() {
        val req = mockRequest()
        val res = mockResponse()

        val chain = FilterChain { _, _ -> assertNotNull(MDC.get(CorrelationIdFilter.MDC_KEY)) }
        filter.doFilter(req, res, chain)

        assertNull(MDC.get(CorrelationIdFilter.MDC_KEY))
        assertNull(MDC.get(CorrelationIdFilter.SESSION_MDC_KEY))
    }

    @Test
    fun `cleans MDC even if filter chain throws`() {
        val req = mockRequest()
        val res = mockResponse()

        val chain = FilterChain { _, _ -> throw RuntimeException("boom") }
        try {
            filter.doFilter(req, res, chain)
        } catch (_: RuntimeException) { }

        assertNull(MDC.get(CorrelationIdFilter.MDC_KEY))
        assertNull(MDC.get(CorrelationIdFilter.SESSION_MDC_KEY))
    }

    @Test
    fun `propagates session id to MDC when provided`() {
        val req = mockRequest(sessionId = "sess1234")
        val res = mockResponse()
        var capturedSessionId: String? = null

        val chain = FilterChain { _, _ -> capturedSessionId = MDC.get(CorrelationIdFilter.SESSION_MDC_KEY) }
        filter.doFilter(req, res, chain)

        assertEquals("sess1234", capturedSessionId)
        assertNull(MDC.get(CorrelationIdFilter.SESSION_MDC_KEY))
    }

    @Test
    fun `skips session MDC when no session header`() {
        val req = mockRequest()
        val res = mockResponse()
        var capturedSessionId: String? = "not-null"

        val chain = FilterChain { _, _ -> capturedSessionId = MDC.get(CorrelationIdFilter.SESSION_MDC_KEY) }
        filter.doFilter(req, res, chain)

        assertNull(capturedSessionId)
    }

    @Test
    fun `strips control characters from incoming requestId`() {
        val req = mockRequest(requestId = "abc\r\n123")
        val res = mockResponse()
        var capturedId: String? = null

        val chain = FilterChain { _, _ -> capturedId = MDC.get(CorrelationIdFilter.MDC_KEY) }
        filter.doFilter(req, res, chain)

        assertEquals("abc123", capturedId)
    }

    @Test
    fun `truncates excessively long requestId`() {
        val longId = "a".repeat(200)
        val req = mockRequest(requestId = longId)
        val res = mockResponse()
        var capturedId: String? = null

        val chain = FilterChain { _, _ -> capturedId = MDC.get(CorrelationIdFilter.MDC_KEY) }
        filter.doFilter(req, res, chain)

        assertEquals(64, capturedId!!.length)
    }

    @Test
    fun `generates new id when incoming requestId is blank`() {
        val req = mockRequest(requestId = "   ")
        val res = mockResponse()
        var capturedId: String? = null

        val chain = FilterChain { _, _ -> capturedId = MDC.get(CorrelationIdFilter.MDC_KEY) }
        filter.doFilter(req, res, chain)

        assertNotNull(capturedId)
        assertEquals(8, capturedId!!.length)
    }

    @Test
    fun `generates new id when sanitized requestId becomes empty`() {
        val req = mockRequest(requestId = "###\$\$\$")
        val res = mockResponse()
        var capturedId: String? = null

        val chain = FilterChain { _, _ -> capturedId = MDC.get(CorrelationIdFilter.MDC_KEY) }
        filter.doFilter(req, res, chain)

        assertNotNull(capturedId)
        assertEquals(8, capturedId!!.length)
    }
}
