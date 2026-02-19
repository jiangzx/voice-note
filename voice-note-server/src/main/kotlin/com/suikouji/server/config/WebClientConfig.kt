package com.suikouji.server.config

import io.netty.channel.ChannelOption
import jakarta.annotation.PreDestroy
import org.slf4j.MDC
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.http.client.reactive.ReactorClientHttpConnector
import org.springframework.web.reactive.function.client.ClientRequest
import org.springframework.web.reactive.function.client.ExchangeFilterFunction
import org.springframework.web.reactive.function.client.WebClient
import reactor.netty.http.client.HttpClient
import reactor.netty.resources.ConnectionProvider
import java.time.Duration

@Configuration
class WebClientConfig {

    private val connectionProvider: ConnectionProvider = ConnectionProvider.builder("dashscope")
        .maxConnections(50)
        .maxIdleTime(Duration.ofSeconds(30))
        .maxLifeTime(Duration.ofMinutes(5))
        .evictInBackground(Duration.ofSeconds(30))
        .build()

    @PreDestroy
    fun destroy() {
        if (!connectionProvider.isDisposed) {
            connectionProvider.dispose()
        }
    }

    @Bean
    fun dashScopeWebClient(properties: DashScopeProperties): WebClient {
        val httpClient = HttpClient.create(connectionProvider)
            .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 5_000)
            .responseTimeout(Duration.ofSeconds(30))

        return WebClient.builder()
            .baseUrl(properties.baseUrl)
            .defaultHeader(HttpHeaders.AUTHORIZATION, "Bearer ${properties.apiKey}")
            .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
            .filter(propagateRequestId())
            .clientConnector(ReactorClientHttpConnector(httpClient))
            .build()
    }

    private fun propagateRequestId(): ExchangeFilterFunction =
        ExchangeFilterFunction.ofRequestProcessor { request ->
            val requestId = MDC.get(CorrelationIdFilter.MDC_KEY)
            if (requestId != null) {
                val modified = ClientRequest.from(request)
                    .header(CorrelationIdFilter.HEADER_NAME, requestId)
                    .build()
                reactor.core.publisher.Mono.just(modified)
            } else {
                reactor.core.publisher.Mono.just(request)
            }
        }
}
