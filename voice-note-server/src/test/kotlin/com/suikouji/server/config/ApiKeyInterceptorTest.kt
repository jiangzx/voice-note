package com.suikouji.server.config

import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.junit.jupiter.api.Test
import java.io.PrintWriter
import java.io.StringWriter
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ApiKeyInterceptorTest {

    private fun mockRequest(apiKey: String? = null): HttpServletRequest {
        val req = mockk<HttpServletRequest>()
        every { req.getHeader("X-API-Key") } returns apiKey
        every { req.remoteAddr } returns "127.0.0.1"
        return req
    }

    private fun mockResponse(): Pair<HttpServletResponse, StringWriter> {
        val res = mockk<HttpServletResponse>(relaxed = true)
        val writer = StringWriter()
        every { res.writer } returns PrintWriter(writer)
        return res to writer
    }

    @Test
    fun `allows all requests when auth is disabled`() {
        val interceptor = ApiKeyInterceptor(ApiKeyProperties(enabled = false, key = "secret"))
        val req = mockRequest(apiKey = null)
        val (res, _) = mockResponse()

        assertTrue(interceptor.preHandle(req, res, Any()))
    }

    @Test
    fun `allows request with valid API key`() {
        val interceptor = ApiKeyInterceptor(ApiKeyProperties(enabled = true, key = "my-secret"))
        val req = mockRequest(apiKey = "my-secret")
        val (res, _) = mockResponse()

        assertTrue(interceptor.preHandle(req, res, Any()))
    }

    @Test
    fun `rejects request with invalid API key`() {
        val interceptor = ApiKeyInterceptor(ApiKeyProperties(enabled = true, key = "correct-key"))
        val req = mockRequest(apiKey = "wrong-key")
        val (res, _) = mockResponse()

        assertFalse(interceptor.preHandle(req, res, Any()))
        verify { res.status = 401 }
    }

    @Test
    fun `rejects request with missing API key`() {
        val interceptor = ApiKeyInterceptor(ApiKeyProperties(enabled = true, key = "correct-key"))
        val req = mockRequest(apiKey = null)
        val (res, _) = mockResponse()

        assertFalse(interceptor.preHandle(req, res, Any()))
        verify { res.status = 401 }
    }

    @Test
    fun `rejects request with blank API key`() {
        val interceptor = ApiKeyInterceptor(ApiKeyProperties(enabled = true, key = "correct-key"))
        val req = mockRequest(apiKey = "   ")
        val (res, _) = mockResponse()

        assertFalse(interceptor.preHandle(req, res, Any()))
        verify { res.status = 401 }
    }

    @Test
    fun `401 response body contains error JSON`() {
        val interceptor = ApiKeyInterceptor(ApiKeyProperties(enabled = true, key = "secret"))
        val req = mockRequest(apiKey = "bad")
        val (res, writer) = mockResponse()

        interceptor.preHandle(req, res, Any())

        val body = writer.toString()
        assertTrue(body.contains("unauthorized"))
        assertTrue(body.contains("Invalid or missing API key"))
    }

    @Test
    fun `401 response sets content type with charset`() {
        val interceptor = ApiKeyInterceptor(ApiKeyProperties(enabled = true, key = "secret"))
        val req = mockRequest(apiKey = "bad")
        val (res, _) = mockResponse()

        interceptor.preHandle(req, res, Any())

        verify { res.contentType = "application/json;charset=UTF-8" }
    }
}
