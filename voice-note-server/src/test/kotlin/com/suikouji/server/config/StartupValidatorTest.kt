package com.suikouji.server.config

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow
import org.junit.jupiter.api.assertThrows

class StartupValidatorTest {

    @Test
    fun `passes with valid DashScope key and auth disabled`() {
        val validator = StartupValidator(
            dashScope = DashScopeProperties(apiKey = "sk-real-key"),
            apiKeyProperties = ApiKeyProperties(enabled = false)
        )
        assertDoesNotThrow { validator.validate() }
    }

    @Test
    fun `fails when DashScope API key is blank`() {
        val validator = StartupValidator(
            dashScope = DashScopeProperties(apiKey = "  "),
            apiKeyProperties = ApiKeyProperties(enabled = false)
        )
        assertThrows<IllegalArgumentException> { validator.validate() }
    }

    @Test
    fun `fails when DashScope API key is placeholder`() {
        val validator = StartupValidator(
            dashScope = DashScopeProperties(apiKey = "your-api-key-here"),
            apiKeyProperties = ApiKeyProperties(enabled = false)
        )
        assertThrows<IllegalArgumentException> { validator.validate() }
    }

    @Test
    fun `passes with auth enabled and valid key`() {
        val validator = StartupValidator(
            dashScope = DashScopeProperties(apiKey = "sk-valid"),
            apiKeyProperties = ApiKeyProperties(enabled = true, key = "secret-key")
        )
        assertDoesNotThrow { validator.validate() }
    }

    @Test
    fun `fails when auth enabled but key is blank`() {
        val validator = StartupValidator(
            dashScope = DashScopeProperties(apiKey = "sk-valid"),
            apiKeyProperties = ApiKeyProperties(enabled = true, key = "")
        )
        assertThrows<IllegalArgumentException> { validator.validate() }
    }
}
