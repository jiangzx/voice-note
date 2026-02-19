package com.suikouji.server.config

import org.slf4j.LoggerFactory
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.event.EventListener
import org.springframework.stereotype.Component

/**
 * Validates critical configuration at startup and fails fast with
 * clear error messages if required settings are missing or invalid.
 */
@Component
class StartupValidator(
    private val dashScope: DashScopeProperties,
    private val apiKeyProperties: ApiKeyProperties
) {

    private val log = LoggerFactory.getLogger(javaClass)

    @EventListener(ApplicationReadyEvent::class)
    fun validate() {
        validateDashScopeApiKey()
        validateApiAuthKey()
        log.info("Startup validation passed — all required configuration is present")
    }

    private fun validateDashScopeApiKey() {
        val key = dashScope.apiKey.trim()
        require(key.isNotBlank()) {
            """
            |
            |========================================
            | DASHSCOPE_API_KEY is not configured!
            |========================================
            | Set the environment variable before starting the server:
            |   export DASHSCOPE_API_KEY=sk-your-actual-key
            |
            | Get your API key from: https://bailian.console.aliyun.com/
            |========================================
            """.trimMargin()
        }
        require(!key.startsWith("your-")) {
            """
            |
            |========================================
            | DASHSCOPE_API_KEY contains a placeholder value!
            |========================================
            | Replace it with your actual DashScope API key:
            |   export DASHSCOPE_API_KEY=sk-your-actual-key
            |
            | Get your API key from: https://bailian.console.aliyun.com/
            |========================================
            """.trimMargin()
        }
        log.info("DashScope API key configured")
    }

    private fun validateApiAuthKey() {
        if (!apiKeyProperties.enabled) {
            log.info("API key authentication is disabled")
            return
        }
        require(apiKeyProperties.key.isNotBlank()) {
            """
            |
            |========================================
            | API_AUTH_KEY is not configured!
            |========================================
            | API key authentication is enabled (api-auth.enabled=true)
            | but API_AUTH_KEY is empty.
            |
            | Set the environment variable:
            |   export API_AUTH_KEY=your-secret-key
            |========================================
            """.trimMargin()
        }
        log.info("API key authentication is enabled")
    }
}
