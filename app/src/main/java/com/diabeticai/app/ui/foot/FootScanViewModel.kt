package com.diabeticai.app.ui.foot

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.diabeticai.app.data.model.PredictionResult
import com.diabeticai.app.data.model.PredictionType
import com.diabeticai.app.data.model.RiskLevel

class FootScanViewModel : ViewModel() {
    private val _footScanResult = MutableLiveData<PredictionResult?>()
    val footScanResult: LiveData<PredictionResult?> = _footScanResult

    fun runFootAnalysis() {
        _footScanResult.value = PredictionResult(
            type = PredictionType.FOOT_ULCER_SCAN,
            title = "Foot Ulcer Screening",
            date = "Today",
            riskLevel = RiskLevel.HEALTHY,
            predictionLabel = "No Ulcer Detected (Grade 0 Normal)",
            riskPercentage = 2.6,
            confidencePercentage = 97.4,
            recommendations = listOf(
                "Maintain daily foot hygiene and moisturize skin.",
                "Inspect feet daily for cuts, blisters, or redness.",
                "Wear comfortable non-binding protective footwear."
            )
        )
    }
}
