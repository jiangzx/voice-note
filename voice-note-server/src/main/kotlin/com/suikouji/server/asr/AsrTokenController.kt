package com.suikouji.server.asr

import kotlinx.coroutines.slf4j.MDCContext
import kotlinx.coroutines.withContext
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/v1/asr")
class AsrTokenController(private val asrTokenService: AsrTokenService) {

    @PostMapping("/token")
    suspend fun generateToken(): AsrTokenResponse = withContext(MDCContext()) {
        asrTokenService.generateTemporaryToken()
    }
}
