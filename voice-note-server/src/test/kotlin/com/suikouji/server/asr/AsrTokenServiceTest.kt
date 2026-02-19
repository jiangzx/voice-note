package com.suikouji.server.asr

import com.suikouji.server.config.DashScopeProperties
import kotlinx.coroutines.test.runTest
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.web.reactive.function.client.WebClient
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AsrTokenServiceTest {

    private lateinit var mockServer: MockWebServer
    private lateinit var service: AsrTokenService

    private val properties = DashScopeProperties(
        apiKey = "test-api-key",
        baseUrl = "wss://dashscope.example.com",
        asr = DashScopeProperties.Asr(
            tokenTtlSeconds = 120,
            model = "qwen3-asr-flash-realtime",
            wsEndpoint = "/api-ws/v1/realtime"
        )
    )

    @BeforeEach
    fun setup() {
        mockServer = MockWebServer()
        mockServer.start()

        val webClient = WebClient.builder()
            .baseUrl(mockServer.url("/").toString())
            .build()

        service = AsrTokenService(webClient, properties)
    }

    @AfterEach
    fun tearDown() {
        mockServer.shutdown()
    }

    @Test
    fun `generates temporary token from DashScope API`() = runTest {
        mockServer.enqueue(
            MockResponse()
                .setBody("""{"token":"st-test-token-123","expires_at":1744080369}""")
                .addHeader("Content-Type", "application/json")
        )

        val result = service.generateTemporaryToken()

        assertEquals("st-test-token-123", result.token)
        assertEquals(1744080369L, result.expiresAt)
        assertEquals("qwen3-asr-flash-realtime", result.model)
    }

    @Test
    fun `includes TTL as query parameter`() = runTest {
        mockServer.enqueue(
            MockResponse()
                .setBody("""{"token":"st-abc","expires_at":9999999999}""")
                .addHeader("Content-Type", "application/json")
        )

        service.generateTemporaryToken()

        val request = mockServer.takeRequest()
        assertTrue(request.path!!.contains("expire_in_seconds=120"))
    }

    @Test
    fun `constructs correct WebSocket URL from config`() = runTest {
        mockServer.enqueue(
            MockResponse()
                .setBody("""{"token":"st-ws","expires_at":9999999999}""")
                .addHeader("Content-Type", "application/json")
        )

        val result = service.generateTemporaryToken()

        assertEquals("wss://dashscope.example.com/api-ws/v1/realtime", result.wsUrl)
    }

    @Test
    fun `uses POST method to generate token`() = runTest {
        mockServer.enqueue(
            MockResponse()
                .setBody("""{"token":"st-method","expires_at":9999999999}""")
                .addHeader("Content-Type", "application/json")
        )

        service.generateTemporaryToken()

        val request = mockServer.takeRequest()
        assertEquals("POST", request.method)
    }
}
