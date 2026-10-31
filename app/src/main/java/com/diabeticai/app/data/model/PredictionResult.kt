package com.diabeticai.app.data.model

enum class RiskLevel {
    HEALTHY, PREDIABETIC, DIABETIC, HIGH_RISK
}

enum class PredictionType {
    DIABETES_ASSESSMENT, FOOT_ULCER_SCAN, RETINA_SCAN
}

data class PredictionResult(
    val id: String = "",
    val type: PredictionType,
    val title: String,
    val date: String,
    val riskLevel: RiskLevel,
    val predictionLabel: String,
    val riskPercentage: Double,
    val confidencePercentage: Double,
    val recommendations: List<String> = emptyList()
)
