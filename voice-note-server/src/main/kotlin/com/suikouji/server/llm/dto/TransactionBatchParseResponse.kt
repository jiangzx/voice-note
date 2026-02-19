package com.suikouji.server.llm.dto

/** Batch response wrapping multiple parsed transactions from a single input. */
data class TransactionBatchParseResponse(
    val transactions: List<TransactionParseResponse>,
    val model: String = ""
)
