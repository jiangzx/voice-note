package com.suikouji.server.llm.dto

import com.fasterxml.jackson.annotation.JsonCreator
import com.fasterxml.jackson.annotation.JsonValue

data class TransactionCorrectionResponse(
    val corrections: List<CorrectionItem> = emptyList(),
    val intent: CorrectionIntent = CorrectionIntent.UNCLEAR,
    val confidence: Double = 0.0,
    val model: String = ""
)

data class CorrectionItem(
    val index: Int,
    val updatedFields: Map<String, Any?> = emptyMap()
)

enum class CorrectionIntent(@get:JsonValue val value: String) {
    CORRECTION("correction"),
    CONFIRM("confirm"),
    CANCEL("cancel"),
    UNCLEAR("unclear"),
    APPEND("append");

    companion object {
        @JvmStatic
        @JsonCreator
        fun fromValue(value: String): CorrectionIntent =
            entries.firstOrNull { it.value.equals(value, ignoreCase = true) } ?: UNCLEAR
    }
}
