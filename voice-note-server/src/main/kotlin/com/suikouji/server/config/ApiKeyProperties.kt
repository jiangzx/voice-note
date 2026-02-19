package com.suikouji.server.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "api-auth")
data class ApiKeyProperties(
    val enabled: Boolean = false,
    val key: String = ""
)
