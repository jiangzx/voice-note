package com.suikouji.server.llm.dto

import com.fasterxml.jackson.annotation.JsonProperty

/** Structured transaction data extracted by LLM from natural language. */
data class TransactionParseResponse(
    val amount: Double?,
    val currency: String = "CNY",
    val date: String?,
    val category: String?,
    val description: String?,
    val type: TransactionType?,
    val account: String?,
    @JsonProperty("transfer_direction") val transferDirection: String? = null,
    val counterparty: String? = null,
    val confidence: Double = 0.0,
    val model: String = ""
)

enum class TransactionType {
    EXPENSE, INCOME, TRANSFER
}
