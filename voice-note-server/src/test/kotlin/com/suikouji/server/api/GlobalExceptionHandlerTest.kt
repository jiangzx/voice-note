package com.suikouji.server.api

import com.suikouji.server.llm.LlmParseException
import org.junit.jupiter.api.Test
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.validation.MapBindingResult
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.reactive.function.client.WebClientResponseException
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GlobalExceptionHandlerTest {

    private val handler = GlobalExceptionHandler()

    @Test
    fun `handleLlmParseException returns 422 with message`() {
        val response = handler.handleLlmParseException(LlmParseException("parse error"))
        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, response.statusCode)
        assertEquals("llm_parse_failed", response.body?.error)
        assertEquals("parse error", response.body?.message)
    }

    @Test
    fun `handleUpstreamError returns 502 with status info`() {
        val ex = WebClientResponseException.create(
            503, "Service Unavailable", HttpHeaders.EMPTY, ByteArray(0), null
        )
        val response = handler.handleUpstreamError(ex)
        assertEquals(HttpStatus.BAD_GATEWAY, response.statusCode)
        assertEquals("upstream_error", response.body?.error)
        assertTrue(response.body?.message?.contains("503") == true)
    }

    @Test
    fun `handleValidation returns 400 with field errors`() {
        val bindingResult = MapBindingResult(mutableMapOf<String, Any>(), "request")
        bindingResult.rejectValue("text", "NotBlank", "must not be blank")
        val ex = MethodArgumentNotValidException(
            org.springframework.core.MethodParameter(
                Any::class.java.getDeclaredMethod("toString"), -1
            ),
            bindingResult
        )
        val response = handler.handleValidation(ex)
        assertEquals(HttpStatus.BAD_REQUEST, response.statusCode)
        assertEquals("validation_failed", response.body?.error)
        assertTrue(response.body?.message?.contains("text") == true)
    }

    @Test
    fun `handleGeneric returns 500 with fixed message`() {
        val response = handler.handleGeneric(RuntimeException("unexpected"))
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.statusCode)
        assertEquals("internal_error", response.body?.error)
        assertEquals("An unexpected error occurred", response.body?.message)
    }
}
