package com.suikouji.server.llm.dto

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotEmpty
import jakarta.validation.constraints.Size

data class TransactionCorrectionRequest(
    @field:NotEmpty
    @field:Size(max = 10, message = "Batch cannot exceed 10 items")
    @field:Valid
    val currentBatch: List<BatchItem>,

    @field:NotBlank
    @field:Size(max = 2000, message = "Correction text must be at most 2000 characters")
    val correctionText: String,

    @field:Valid
    val context: ParseContext? = null
)

data class BatchItem(
    val index: Int,
    val amount: Double?,
    @field:Size(max = 100, message = "Category must be at most 100 characters")
    val category: String?,
    @field:Size(max = 20, message = "Type must be at most 20 characters")
    val type: String?,
    @field:Size(max = 500, message = "Description must be at most 500 characters")
    val description: String?,
    @field:Size(max = 30, message = "Date must be at most 30 characters")
    val date: String? = null
)
