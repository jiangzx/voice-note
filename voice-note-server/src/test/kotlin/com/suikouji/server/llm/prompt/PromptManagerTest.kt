package com.suikouji.server.llm.prompt

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PromptManagerTest {

    private val manager = PromptManager()

    @Test
    fun `loads existing prompt template`() {
        val prompt = manager.getPrompt("transaction-parse")
        assertTrue(prompt.isNotBlank())
        assertTrue(prompt.contains("JSON"))
    }

    @Test
    fun `caches prompt after first load`() {
        val first = manager.getPrompt("transaction-parse")
        val second = manager.getPrompt("transaction-parse")
        // Same object reference — cached
        assertTrue(first === second)
    }

    @Test
    fun `throws for missing prompt template`() {
        val ex = assertThrows<IllegalArgumentException> {
            manager.getPrompt("nonexistent-template")
        }
        assertTrue(ex.message!!.contains("not found"))
    }

    @Test
    fun `loaded prompt is trimmed`() {
        val prompt = manager.getPrompt("transaction-parse")
        assertEquals(prompt, prompt.trim())
    }
}
