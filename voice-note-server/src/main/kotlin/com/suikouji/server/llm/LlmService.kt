package com.suikouji.server.llm

import com.fasterxml.jackson.databind.ObjectMapper
import com.suikouji.server.llm.dto.BatchItem
import com.suikouji.server.llm.dto.ParseContext
import com.suikouji.server.llm.dto.TransactionBatchParseResponse
import com.suikouji.server.llm.dto.TransactionCorrectionRequest
import com.suikouji.server.llm.dto.TransactionCorrectionResponse
import com.suikouji.server.llm.dto.TransactionParseRequest
import com.suikouji.server.llm.prompt.PromptManager
import com.suikouji.server.llm.provider.LlmProvider
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Qualifier
import org.springframework.stereotype.Service

@Service
class LlmService(
    @Qualifier("primaryLlmProvider") private val primaryProvider: LlmProvider,
    @Qualifier("fallbackLlmProvider") private val fallbackProvider: LlmProvider,
    private val promptManager: PromptManager,
    private val objectMapper: ObjectMapper
) {
    private val log = LoggerFactory.getLogger(javaClass)

    /**
     * Parse user's natural language input into structured transaction data.
     * Returns a batch response containing one or more transactions.
     * Uses primary model first; falls back to a stronger model on failure.
     */
    suspend fun parseTransaction(request: TransactionParseRequest): TransactionBatchParseResponse {
        val systemPrompt = buildSystemPrompt(request)
        val userMessage = request.text
        log.debug("parseTransaction: textLength={}", userMessage.length)

        val primary = tryParseBatch(primaryProvider, systemPrompt, userMessage)
        if (primary != null) return primary

        log.warn("Primary model failed, trying fallback: primary={}, fallback={}", primaryProvider.modelName, fallbackProvider.modelName)
        val fallback = tryParseBatch(fallbackProvider, systemPrompt, userMessage)
        if (fallback != null) return fallback

        log.error("Both models failed: textLength={}", userMessage.length)
        throw LlmParseException("Both primary and fallback models failed to parse")
    }

    private suspend fun tryParseBatch(
        provider: LlmProvider,
        systemPrompt: String,
        userMessage: String
    ): TransactionBatchParseResponse? = try {
        val raw = provider.chatCompletion(systemPrompt, userMessage)
        val json = extractJson(raw)
        val batchResult = objectMapper.readValue(json, TransactionBatchParseResponse::class.java)
        require(batchResult.transactions.isNotEmpty()) { "Empty transactions array" }
        batchResult.copy(model = provider.modelName)
    } catch (e: com.fasterxml.jackson.core.JsonProcessingException) {
        log.warn("JSON parse error with model={}: {}", provider.modelName, e.originalMessage)
        null
    } catch (e: IllegalArgumentException) {
        log.warn("Validation failed with model={}: {}", provider.modelName, e.message)
        null
    } catch (e: org.springframework.web.reactive.function.client.WebClientResponseException) {
        log.warn("Upstream API error with model={}: status={}", provider.modelName, e.statusCode)
        null
    } catch (e: Exception) {
        log.warn("LLM parse failed with model={}: {} - {}", provider.modelName, e.javaClass.simpleName, e.message)
        null
    }

    /**
     * Process a correction request against a batch of pending transactions.
     * Sends batch context + user correction text to LLM, returns structured corrections.
     * Uses primary model first; falls back to a stronger model on failure.
     */
    suspend fun correctTransaction(request: TransactionCorrectionRequest): TransactionCorrectionResponse {
        val systemPrompt = buildCorrectionPrompt(request)
        val userMessage = request.correctionText
        log.debug("correctTransaction: batchSize={}, textLength={}", request.currentBatch.size, userMessage.length)

        val primary = tryCorrect(primaryProvider, systemPrompt, userMessage, request.currentBatch.size)
        if (primary != null) return primary

        log.warn("Primary correction failed, trying fallback: primary={}, fallback={}", primaryProvider.modelName, fallbackProvider.modelName)
        val fallback = tryCorrect(fallbackProvider, systemPrompt, userMessage, request.currentBatch.size)
        if (fallback != null) return fallback

        log.error("Both models failed correction: textLength={}", userMessage.length)
        throw LlmParseException("Both primary and fallback models failed to correct")
    }

    private suspend fun tryCorrect(
        provider: LlmProvider,
        systemPrompt: String,
        userMessage: String,
        batchSize: Int
    ): TransactionCorrectionResponse? = try {
        val raw = provider.chatCompletion(systemPrompt, userMessage)
        val json = extractJson(raw)
        val result = objectMapper.readValue(json, TransactionCorrectionResponse::class.java)
        val validated = validateCorrection(result, batchSize)
        validated.copy(model = provider.modelName)
    } catch (e: com.fasterxml.jackson.core.JsonProcessingException) {
        log.warn("Correction JSON parse error with model={}: {}", provider.modelName, e.originalMessage)
        null
    } catch (e: IllegalArgumentException) {
        log.warn("Correction validation failed with model={}: {}", provider.modelName, e.message)
        null
    } catch (e: org.springframework.web.reactive.function.client.WebClientResponseException) {
        log.warn("Upstream API error during correction with model={}: status={}", provider.modelName, e.statusCode)
        null
    } catch (e: Exception) {
        log.warn("LLM correction failed with model={}: {} - {}", provider.modelName, e.javaClass.simpleName, e.message)
        null
    }

    /** Filter out corrections with out-of-range indices (keep -1 for append). */
    private fun validateCorrection(response: TransactionCorrectionResponse, batchSize: Int): TransactionCorrectionResponse {
        val filtered = response.corrections.filter { item ->
            item.index == -1 || item.index in 0 until batchSize
        }
        if (filtered.size < response.corrections.size) {
            log.warn("Filtered {} out-of-range correction indices", response.corrections.size - filtered.size)
        }
        return response.copy(corrections = filtered)
    }

    private fun buildCorrectionPrompt(request: TransactionCorrectionRequest): String {
        val base = promptManager.getPrompt("correction-dialogue")
        val batchContext = formatBatchContext(request.currentBatch)
        val prompt = base
            .replace("{batchContext}", batchContext)
            .replace("{correctionText}", request.correctionText)
        return appendContextSuffix(prompt, request.context)
    }

    private fun formatBatchContext(batch: List<BatchItem>): String =
        batch.joinToString("\n") { item ->
            val type = item.type ?: "EXPENSE"
            val amount = item.amount?.let { "${it}元" } ?: "?元"
            val category = item.category ?: "未分类"
            val desc = item.description ?: ""
            val date = item.date?.let { " $it" } ?: ""
            "#${item.index}: $type $amount $category $desc$date"
        }

    private fun buildSystemPrompt(request: TransactionParseRequest): String {
        val base = promptManager.getPrompt("transaction-parse")
        return appendContextSuffix(base, request.context)
    }

    private fun appendContextSuffix(base: String, context: ParseContext?): String {
        context ?: return base
        val extra = buildString {
            context.customCategories?.let { append("\nUser custom categories: ${sanitizeList(it)}") }
            context.recentCategories?.let { append("\nRecently used categories: ${sanitizeList(it)}") }
            context.accounts?.let { append("\nUser accounts: ${sanitizeList(it)}") }
        }
        return base + extra
    }

    /** Strip control chars and cap length to prevent prompt injection. */
    private fun sanitizeList(items: List<String>): String =
        items.map { it.replace(Regex("[\\n\\r\\t]"), " ").take(50) }
            .take(30)
            .joinToString()

    /** Extract JSON object from LLM response that may contain markdown fences. */
    private fun extractJson(raw: String): String {
        val trimmed = raw.trim()
        if (trimmed.startsWith("{")) return trimmed

        val start = trimmed.indexOf('{')
        val end = trimmed.lastIndexOf('}')
        if (start >= 0 && end > start) return trimmed.substring(start, end + 1)

        log.debug("No JSON found in LLM response: {}", trimmed.take(200))
        throw LlmParseException("LLM response did not contain valid JSON")
    }
}

class LlmParseException(message: String) : RuntimeException(message)
