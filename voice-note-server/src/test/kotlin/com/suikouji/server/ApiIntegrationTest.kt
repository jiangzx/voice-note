package com.suikouji.server

import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import okhttp3.mockwebserver.Dispatcher
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import com.suikouji.server.asr.AsrTokenService
import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.web.client.TestRestTemplate
import org.springframework.http.HttpEntity
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.test.context.ActiveProfiles
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * Full integration test against Spring Boot endpoints with a
 * MockWebServer standing in for DashScope.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
class ApiIntegrationTest {

    companion object {
        private val mockDashScope = MockWebServer()

        @BeforeAll
        @JvmStatic
        fun startMock() {
            mockDashScope.start()
        }

        @AfterAll
        @JvmStatic
        fun stopMock() {
            mockDashScope.shutdown()
        }

        @DynamicPropertySource
        @JvmStatic
        fun overrideProperties(registry: DynamicPropertyRegistry) {
            registry.add("dashscope.base-url") {
                mockDashScope.url("/").toString().trimEnd('/')
            }
        }
    }

    @Autowired
    private lateinit var restTemplate: TestRestTemplate

    @Autowired
    private lateinit var asrTokenService: AsrTokenService

    @BeforeEach
    fun clearCaches() {
        asrTokenService.evictCache()
    }

    // ===================== ASR Token =====================

    @Test
    fun `POST asr token returns valid response`() {
        mockDashScope.dispatcher = singleResponseDispatcher(
            MockResponse()
                .setBody("""{"token":"st-integration-token","expires_at":1800000000}""")
                .addHeader("Content-Type", "application/json")
        )

        val response = restTemplate.postForEntity(
            "/api/v1/asr/token",
            null,
            Map::class.java
        )

        assertEquals(HttpStatus.OK, response.statusCode)

        val body = response.body!!
        assertEquals("st-integration-token", body["token"])
        assertEquals("qwen3-asr-flash-realtime", body["model"])
        assertNotNull(body["wsUrl"])
        assertTrue((body["wsUrl"] as String).contains("/api-ws/v1/realtime"))
    }

    @Test
    fun `POST asr token returns 502 on upstream failure`() {
        mockDashScope.dispatcher = singleResponseDispatcher(
            MockResponse().setResponseCode(500).setBody("Internal Server Error")
        )

        val response = restTemplate.postForEntity(
            "/api/v1/asr/token",
            null,
            Map::class.java
        )

        assertEquals(HttpStatus.BAD_GATEWAY, response.statusCode)
    }

    // ===================== LLM Parse =====================

    @Test
    fun `POST llm parse-transaction returns parsed data`() {
        mockDashScope.dispatcher = singleResponseDispatcher(
            chatCompletionMock("""{"transactions":[{"amount":42.5,"currency":"CNY","date":"2026-02-17","category":"餐饮","description":"午餐","type":"EXPENSE","account":null,"confidence":0.95}]}""")
        )

        val headers = HttpHeaders()
        headers.contentType = MediaType.APPLICATION_JSON
        val request = HttpEntity("""{"text":"午餐42块5"}""", headers)

        val response = restTemplate.postForEntity(
            "/api/v1/llm/parse-transaction",
            request,
            Map::class.java
        )

        assertEquals(HttpStatus.OK, response.statusCode)

        val body = response.body!!
        val transactions = body["transactions"] as List<*>
        val firstTransaction = transactions.first() as Map<*, *>
        assertEquals(42.5, firstTransaction["amount"])
        assertEquals("餐饮", firstTransaction["category"])
        assertEquals("qwen-turbo", body["model"])
    }

    @Test
    fun `POST llm parse-transaction with empty text returns 400`() {
        val headers = HttpHeaders()
        headers.contentType = MediaType.APPLICATION_JSON
        val request = HttpEntity("""{"text":""}""", headers)

        val response = restTemplate.postForEntity(
            "/api/v1/llm/parse-transaction",
            request,
            Map::class.java
        )

        assertEquals(HttpStatus.BAD_REQUEST, response.statusCode)
    }

    @Test
    fun `POST llm parse-transaction falls back on primary failure`() {
        // Primary model retries 2 times (3 total), so first 3 calls must fail
        val callCount = java.util.concurrent.atomic.AtomicInteger(0)
        mockDashScope.dispatcher = object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse {
                if (callCount.incrementAndGet() <= 3) {
                    return MockResponse().setResponseCode(500).setBody("model overloaded")
                }
                return chatCompletionMock(
                    """{"transactions":[{"amount":10.0,"currency":"CNY","date":null,"category":"交通","description":"地铁","type":"EXPENSE","account":null,"confidence":0.8}]}"""
                )
            }
        }

        val headers = HttpHeaders()
        headers.contentType = MediaType.APPLICATION_JSON
        val request = HttpEntity("""{"text":"地铁10块"}""", headers)

        val response = restTemplate.postForEntity(
            "/api/v1/llm/parse-transaction",
            request,
            Map::class.java
        )

        assertEquals(HttpStatus.OK, response.statusCode)
        assertEquals("qwen-plus", response.body!!["model"])
    }

    @Test
    fun `POST llm parse-transaction returns 422 when both models fail`() {
        mockDashScope.dispatcher = singleResponseDispatcher(
            MockResponse().setResponseCode(500).setBody("all models down")
        )

        val headers = HttpHeaders()
        headers.contentType = MediaType.APPLICATION_JSON
        val request = HttpEntity("""{"text":"一些无意义的输入"}""", headers)

        val response = restTemplate.postForEntity(
            "/api/v1/llm/parse-transaction",
            request,
            Map::class.java
        )

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, response.statusCode)
    }

    // ===================== Helpers =====================

    private fun singleResponseDispatcher(mockResponse: MockResponse): Dispatcher =
        object : Dispatcher() {
            override fun dispatch(request: RecordedRequest): MockResponse = mockResponse
        }

    /** Build a valid OpenAI-compatible chat completion mock with properly escaped content. */
    private fun chatCompletionMock(innerJson: String): MockResponse {
        val om = jacksonObjectMapper()
        val escaped = om.writeValueAsString(innerJson) // produces a JSON string with inner quotes escaped
        val body = """{"choices":[{"message":{"role":"assistant","content":$escaped}}]}"""
        return MockResponse()
            .setBody(body)
            .addHeader("Content-Type", "application/json")
    }
}
