package com.suikouji.server.llm.dto

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size

/** Client request to parse natural language into structured transaction data. */
data class TransactionParseRequest(
    @field:NotBlank
    @field:Size(max = 2000, message = "Text must be at most 2000 characters")
    val text: String,

    @field:Valid
    val context: ParseContext? = null
)

/** Optional context to improve parsing accuracy. */
data class ParseContext(
    @field:Size(max = 50, message = "recentCategories cannot exceed 50 items")
    val recentCategories: List<@Size(max = 100) String>? = null,

    @field:Size(max = 50, message = "customCategories cannot exceed 50 items")
    val customCategories: List<@Size(max = 100) String>? = null,

    @field:Size(max = 20, message = "accounts cannot exceed 20 items")
    val accounts: List<@Size(max = 100) String>? = null
)
