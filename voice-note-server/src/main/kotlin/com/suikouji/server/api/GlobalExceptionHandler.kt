package com.suikouji.server.api

import com.suikouji.server.api.dto.ErrorResponse
import com.suikouji.server.llm.LlmParseException
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.reactive.function.client.WebClientResponseException

@RestControllerAdvice
class GlobalExceptionHandler {

    private val log = LoggerFactory.getLogger(javaClass)

    @ExceptionHandler(LlmParseException::class)
    fun handleLlmParseException(e: LlmParseException): ResponseEntity<ErrorResponse> {
        log.error("LLM parse failed: {}", e.message)
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY)
            .body(ErrorResponse(error = "llm_parse_failed", message = e.message ?: "Parse failed"))
    }

    @ExceptionHandler(WebClientResponseException::class)
    fun handleUpstreamError(e: WebClientResponseException): ResponseEntity<ErrorResponse> {
        log.error("Upstream API error: {} {}", e.statusCode, e.message)
        return ResponseEntity.status(HttpStatus.BAD_GATEWAY)
            .body(ErrorResponse(error = "upstream_error", message = "Upstream service returned ${e.statusCode}"))
    }

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(e: MethodArgumentNotValidException): ResponseEntity<ErrorResponse> {
        val details = e.bindingResult.fieldErrors.joinToString { "${it.field}: ${it.defaultMessage}" }
        return ResponseEntity.badRequest()
            .body(ErrorResponse(error = "validation_failed", message = details))
    }

    @ExceptionHandler(Exception::class)
    fun handleGeneric(e: Exception): ResponseEntity<ErrorResponse> {
        log.error("Unexpected error", e)
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(ErrorResponse(error = "internal_error", message = "An unexpected error occurred"))
    }
}
