package com.suikouji.server

import com.suikouji.server.config.ApiKeyProperties
import com.suikouji.server.config.CorsProperties
import com.suikouji.server.config.DashScopeProperties
import com.suikouji.server.config.RateLimitProperties
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.boot.runApplication

@SpringBootApplication
@EnableConfigurationProperties(
    DashScopeProperties::class,
    RateLimitProperties::class,
    ApiKeyProperties::class,
    CorsProperties::class
)
class VoiceNoteServerApplication

fun main(args: Array<String>) {
	runApplication<VoiceNoteServerApplication>(*args)
}
