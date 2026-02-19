package com.suikouji.server.llm.prompt

import jakarta.annotation.PostConstruct
import org.slf4j.LoggerFactory
import org.springframework.core.io.ClassPathResource
import org.springframework.stereotype.Component
import java.nio.charset.StandardCharsets
import java.util.concurrent.ConcurrentHashMap

/**
 * Loads and caches prompt templates from classpath resources.
 * Templates are read once and cached in memory for fast access.
 */
@Component
class PromptManager {

    private val log = LoggerFactory.getLogger(javaClass)
    private val cache = ConcurrentHashMap<String, String>()

    @PostConstruct
    fun validateRequiredPrompts() {
        getPrompt("transaction-parse")
        getPrompt("correction-dialogue")
    }

    fun getPrompt(name: String): String =
        cache.computeIfAbsent(name) { loadFromClasspath(it) }

    private fun loadFromClasspath(name: String): String {
        val resource = ClassPathResource("prompts/$name.txt")
        if (!resource.exists()) {
            log.error("Prompt template not found: prompts/{}.txt", name)
            throw IllegalArgumentException("Prompt template not found: prompts/$name.txt")
        }
        val content = resource.getContentAsString(StandardCharsets.UTF_8).trim()
        log.info("Loaded prompt template: name={}, length={}", name, content.length)
        return content
    }
}
