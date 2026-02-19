package com.suikouji.server.config

import com.suikouji.server.ratelimit.RateLimitInterceptor
import org.slf4j.LoggerFactory
import org.springframework.context.annotation.Configuration
import org.springframework.web.servlet.config.annotation.CorsRegistry
import org.springframework.web.servlet.config.annotation.InterceptorRegistry
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer

@Configuration
class WebMvcConfig(
    private val rateLimitInterceptor: RateLimitInterceptor,
    private val apiKeyInterceptor: ApiKeyInterceptor,
    private val corsProperties: CorsProperties
) : WebMvcConfigurer {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun addInterceptors(registry: InterceptorRegistry) {
        // API key auth runs first
        registry.addInterceptor(apiKeyInterceptor)
            .addPathPatterns("/api/**")
            .order(0)

        // Rate limiting runs after auth
        registry.addInterceptor(rateLimitInterceptor)
            .addPathPatterns("/api/**")
            .order(1)
    }

    override fun addCorsMappings(registry: CorsRegistry) {
        val origins = corsProperties.allowedOrigins
            .split(",")
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .ifEmpty { listOf("*") }
            .toTypedArray()

        log.info("CORS configured: allowedOrigins={}", origins.contentToString())

        registry.addMapping("/api/**")
            .allowedOrigins(*origins)
            .allowedMethods("GET", "POST", "OPTIONS")
            .allowedHeaders("*")
            .maxAge(3600)
    }
}
