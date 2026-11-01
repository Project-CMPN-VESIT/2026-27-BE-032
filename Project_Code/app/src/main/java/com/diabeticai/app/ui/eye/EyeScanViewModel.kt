package com.diabeticai.app.ui.eye

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.ViewModel
import com.diabeticai.app.data.model.PredictionResult
import com.diabeticai.app.data.model.PredictionType
import com.diabeticai.app.data.model.RiskLevel

class EyeScanViewModel : ViewModel() {
    private val _retinaResult = MutableLiveData<PredictionResult?>()
    val retinaResult: LiveData<PredictionResult?> = _retinaResult

    fun runRetinaAnalysis() {
        _retinaResult.value = PredictionResult(
            type = PredictionType.RETINA_SCAN,
            title = "Retina Retinopathy Scan",
            date = "Today",
            riskLevel = RiskLevel.HEALTHY,
            predictionLabel = "Healthy Fundus - No Retinopathy",
            riskPercentage = 1.1,
            confidencePercentage = 98.9,
            recommendations = listOf(
                "Schedule comprehensive dilated eye exam once a year.",
                "Maintain strict control of blood sugar and blood pressure.",
                "Protect eyes from UV exposure with polarized sunglasses."
            )
        )
    }
}
