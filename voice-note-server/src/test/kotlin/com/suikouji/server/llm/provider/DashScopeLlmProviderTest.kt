package com.suikouji.server.llm.provider

import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.web.reactive.function.client.WebClient
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class DashScopeLlmProviderTest {

    private lateinit var mockServer: MockWebServer
    private lateinit var provider: DashScopeLlmProvider

    @BeforeEach
    fun setup() {
        mockServer = MockWebServer()
        mockServer.start()

        val webClient = WebClient.builder()
            .baseUrl(mockServer.url("/").toString())
            .build()

        provider = DashScopeLlmProvider(
            modelName = "qwen-turbo",
            webClient = webClient,
            maxTokens = 500,
            temperature = 0.1
        )
    }

    @AfterEach
    fun tearDown() {
        mockServer.shutdown()
    }

    @Test
    fun `returns assistant response content`() = runTest {
        mockServer.enqueue(
            MockResponse()
                .setBody("""
                    {"choices":[{"message":{"role":"assistant","content":"Hello from LLM"}}]}
                """.trimIndent())
                .addHeader("Content-Type", "application/json")
        )

        val result = provider.chatCompletion("system prompt", "user message")

        assertEquals("Hello from LLM", result)
    }

    @Test
    fun `sends correct request to chat completions endpoint`() = runTest {
        mockServer.enqueue(
            MockResponse()
                .setBody("""{"choices":[{"message":{"role":"assistant","content":"ok"}}]}""")
                .addHeader("Content-Type", "application/json")
        )

        provider.chatCompletion("You are a parser", "咖啡28块")

        val request = mockServer.takeRequest()
        assertEquals("POST", request.method)
        assertTrue(request.path!!.contains("/compatible-mode/v1/chat/completions"))

        val body = request.body.readUtf8()
        assertTrue(body.contains("qwen-turbo"))
        assertTrue(body.contains("You are a parser"))
        assertTrue(body.contains("咖啡28块"))
    }

    @Test
    fun `throws on empty choices`() = runTest {
        mockServer.enqueue(
            MockResponse()
                .setBody("""{"choices":[]}""")
                .addHeader("Content-Type", "application/json")
        )

        assertThrows<IllegalStateException> {
            provider.chatCompletion("system", "user")
        }
    }

    @Test
    fun `exposes model name`() {
        assertEquals("qwen-turbo", provider.modelName)
    }
}
