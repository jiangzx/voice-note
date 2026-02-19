package com.suikouji.server.llm.provider

import com.fasterxml.jackson.annotation.JsonProperty
import kotlinx.coroutines.reactor.awaitSingle
import org.slf4j.LoggerFactory
import org.springframework.http.MediaType
import org.springframework.web.reactive.function.client.WebClient
import org.springframework.web.reactive.function.client.WebClientResponseException
import reactor.util.retry.Retry
import java.time.Duration

/**
 * LLM provider that calls DashScope via OpenAI-compatible chat completions API.
 * Each instance targets a specific model (e.g. qwen-turbo, qwen-plus).
 */
class DashScopeLlmProvider(
    override val modelName: String,
    private val webClient: WebClient,
    private val maxTokens: Int,
    private val temperature: Double
) : LlmProvider {

    private val log = LoggerFactory.getLogger(javaClass)

    override suspend fun chatCompletion(systemPrompt: String, userMessage: String): String {
        val request = ChatCompletionRequest(
            model = modelName,
            messages = listOf(
                Message(role = "system", content = systemPrompt),
                Message(role = "user", content = userMessage)
            ),
            maxTokens = maxTokens,
            temperature = temperature
        )

        log.debug("Calling DashScope model={} with {} chars input", modelName, userMessage.length)

        val startMs = System.currentTimeMillis()
        val response = webClient
            .post()
            .uri("/compatible-mode/v1/chat/completions")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .retrieve()
            .bodyToMono(ChatCompletionResponse::class.java)
            .retryWhen(
                Retry.backoff(2, Duration.ofMillis(500))
                    .filter { it is WebClientResponseException && it.statusCode.is5xxServerError }
                    .doBeforeRetry { log.warn("Retrying DashScope: attempt={}, error={}", it.totalRetries() + 1, it.failure().message) }
            )
            .awaitSingle()
        val durationMs = System.currentTimeMillis() - startMs

        val content = response.choices.firstOrNull()?.message?.content
        if (content == null) {
            log.error("Empty response from DashScope: model={}, durationMs={}", modelName, durationMs)
            throw IllegalStateException("Empty response from model $modelName")
        }

        log.info("DashScope call success: model={}, durationMs={}, responseChars={}", modelName, durationMs, content.length)
        return content
    }
}

// --- OpenAI-compatible request/response DTOs ---

internal data class ChatCompletionRequest(
    val model: String,
    val messages: List<Message>,
    @JsonProperty("max_tokens") val maxTokens: Int,
    val temperature: Double
)

internal data class Message(
    val role: String,
    val content: String
)

internal data class ChatCompletionResponse(
    val choices: List<Choice>
)

internal data class Choice(
    val message: Message
)
