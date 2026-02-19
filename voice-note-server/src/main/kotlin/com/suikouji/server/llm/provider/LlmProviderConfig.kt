package com.suikouji.server.llm.provider

import com.suikouji.server.config.DashScopeProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.web.reactive.function.client.WebClient

@Configuration
class LlmProviderConfig {

    @Bean
    fun primaryLlmProvider(
        webClient: WebClient,
        properties: DashScopeProperties
    ): LlmProvider = DashScopeLlmProvider(
        modelName = properties.llm.primaryModel,
        webClient = webClient,
        maxTokens = properties.llm.maxTokens,
        temperature = properties.llm.temperature
    )

    @Bean
    fun fallbackLlmProvider(
        webClient: WebClient,
        properties: DashScopeProperties
    ): LlmProvider = DashScopeLlmProvider(
        modelName = properties.llm.fallbackModel,
        webClient = webClient,
        maxTokens = properties.llm.maxTokens,
        temperature = properties.llm.temperature
    )
}
