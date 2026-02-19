package com.suikouji.server.config

import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.slf4j.MDC
import kotlin.test.assertEquals
import kotlin.test.assertNull

class WebClientConfigTest {

    private lateinit var mockServer: MockWebServer
    private lateinit var config: WebClientConfig

    @BeforeEach
    fun setup() {
        mockServer = MockWebServer()
        mockServer.start()
        config = WebClientConfig()
    }

    @AfterEach
    fun tearDown() {
        mockServer.shutdown()
        MDC.clear()
    }

    private fun properties(): DashScopeProperties =
        DashScopeProperties(
            apiKey = "test-key",
            baseUrl = mockServer.url("/").toString()
        )

    @Test
    fun `propagates requestId from MDC to outgoing request header`() {
        mockServer.enqueue(MockResponse().setBody("{}"))
        MDC.put(CorrelationIdFilter.MDC_KEY, "test-req-123")

        val webClient = config.dashScopeWebClient(properties())
        webClient.get().uri("/test").retrieve()
            .bodyToMono(String::class.java)
            .block()

        val recorded = mockServer.takeRequest()
        assertEquals("test-req-123", recorded.getHeader(CorrelationIdFilter.HEADER_NAME))
    }

    @Test
    fun `does not add X-Request-ID header when MDC has no requestId`() {
        mockServer.enqueue(MockResponse().setBody("{}"))

        val webClient = config.dashScopeWebClient(properties())
        webClient.get().uri("/test").retrieve()
            .bodyToMono(String::class.java)
            .block()

        val recorded = mockServer.takeRequest()
        assertNull(recorded.getHeader(CorrelationIdFilter.HEADER_NAME))
    }

    @Test
    fun `includes default Authorization and Content-Type headers`() {
        mockServer.enqueue(MockResponse().setBody("{}"))

        val webClient = config.dashScopeWebClient(properties())
        webClient.get().uri("/test").retrieve()
            .bodyToMono(String::class.java)
            .block()

        val recorded = mockServer.takeRequest()
        assertEquals("Bearer test-key", recorded.getHeader("Authorization"))
        assertEquals("application/json", recorded.getHeader("Content-Type"))
    }
}
