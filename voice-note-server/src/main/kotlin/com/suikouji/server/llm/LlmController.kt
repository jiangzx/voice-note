package com.suikouji.server.llm

import com.suikouji.server.llm.dto.TransactionBatchParseResponse
import com.suikouji.server.llm.dto.TransactionCorrectionRequest
import com.suikouji.server.llm.dto.TransactionCorrectionResponse
import com.suikouji.server.llm.dto.TransactionParseRequest
import jakarta.validation.Valid
import kotlinx.coroutines.slf4j.MDCContext
import kotlinx.coroutines.withContext
import org.slf4j.LoggerFactory
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/llm")
class LlmController(private val llmService: LlmService) {

    private val log = LoggerFactory.getLogger(javaClass)

    @PostMapping("/parse-transaction")
    suspend fun parseTransaction(
        @Valid @RequestBody request: TransactionParseRequest
    ): TransactionBatchParseResponse = withContext(MDCContext()) {
        log.info("parse-transaction: textLength={}", request.text.length)
        llmService.parseTransaction(request)
    }

    @PostMapping("/correct-transaction")
    suspend fun correctTransaction(
        @Valid @RequestBody request: TransactionCorrectionRequest
    ): TransactionCorrectionResponse = withContext(MDCContext()) {
        log.info("correct-transaction: batchSize={}, textLength={}", request.currentBatch.size, request.correctionText.length)
        llmService.correctTransaction(request)
    }
}
