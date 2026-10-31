package com.diabeticai.app.ui.assessment

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.diabeticai.app.data.model.PredictionResult
import com.diabeticai.app.data.model.PredictionType
import com.diabeticai.app.data.model.RiskLevel

class AssessmentViewModel : ViewModel() {

    private val _assessmentResult = MutableLiveData<PredictionResult?>()
    val assessmentResult: LiveData<PredictionResult?> = _assessmentResult

    fun calculateBmi(heightCm: Double, weightKg: Double): Double {
        if (heightCm <= 0) return 0.0
        val heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }

    fun runAssessment(glucose: Double, hba1c: Double) {
        val (riskLevel, label, percentage) = when {
            glucose >= 126 || hba1c >= 6.5 -> Triple(RiskLevel.DIABETIC, "Diabetic - High Risk", 84.5)
            glucose >= 100 || hba1c >= 5.7 -> Triple(RiskLevel.PREDIABETIC, "Prediabetic - Moderate Risk", 42.1)
            else -> Triple(RiskLevel.HEALTHY, "Healthy - Low Risk", 8.2)
        }

        _assessmentResult.value = PredictionResult(
            type = PredictionType.DIABETES_ASSESSMENT,
            title = "Tabular Diabetes Assessment",
            date = "Today",
            riskLevel = riskLevel,
            predictionLabel = label,
            riskPercentage = percentage,
            confidencePercentage = 95.8
        )
    }
}
