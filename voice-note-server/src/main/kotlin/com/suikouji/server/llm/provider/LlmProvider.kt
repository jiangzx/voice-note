package com.suikouji.server.llm.provider

/** Abstraction over LLM provider APIs (OpenAI-compatible interface). */
interface LlmProvider {

    val modelName: String

    /**
     * Send a chat completion request and return the assistant's response content.
     *
     * @param systemPrompt the system-level instruction
     * @param userMessage the user input to process
     * @return raw text response from the model
     */
    suspend fun chatCompletion(systemPrompt: String, userMessage: String): String
}
