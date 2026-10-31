package com.diabeticai.app.data.repository

import com.diabeticai.app.data.model.CarePlan
import com.diabeticai.app.data.model.PredictionResult
import com.diabeticai.app.data.model.PredictionType
import com.diabeticai.app.data.model.RiskLevel
import com.diabeticai.app.data.model.User
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

class DiabeticRepository {

    private val _currentUser = MutableStateFlow(User())
    val currentUser: Flow<User> = _currentUser.asStateFlow()

    private val mockHistory = mutableListOf(
        PredictionResult(
            id = "1",
            type = PredictionType.RETINA_SCAN,
            title = "Retina Retinopathy Scan",
            date = "Aug 28, 2026 • 10:45 AM",
            riskLevel = RiskLevel.HEALTHY,
            predictionLabel = "Healthy Fundus - No Retinopathy",
            riskPercentage = 1.1,
            confidencePercentage = 98.9,
            recommendations = listOf(
                "Schedule comprehensive dilated eye exam once a year.",
                "Maintain strict control of blood sugar and blood pressure.",
                "Protect eyes from UV exposure with polarized sunglasses."
            )
        ),
        PredictionResult(
            id = "2",
            type = PredictionType.FOOT_ULCER_SCAN,
            title = "Foot Ulcer Screening",
            date = "Aug 20, 2026 • 03:15 PM",
            riskLevel = RiskLevel.HEALTHY,
            predictionLabel = "Grade 0 - No Lesion Detected",
            riskPercentage = 2.6,
            confidencePercentage = 97.4,
            recommendations = listOf(
                "Maintain daily foot hygiene and moisturize skin.",
                "Inspect feet daily for cuts, blisters, or redness.",
                "Wear comfortable non-binding protective footwear."
            )
        ),
        PredictionResult(
            id = "3",
            type = PredictionType.DIABETES_ASSESSMENT,
            title = "Tabular Diabetes Assessment",
            date = "Aug 12, 2026 • 09:30 AM",
            riskLevel = RiskLevel.HEALTHY,
            predictionLabel = "Healthy - Low Risk Profile",
            riskPercentage = 8.2,
            confidencePercentage = 95.8,
            recommendations = listOf(
                "Continue 150 mins/week moderate exercise routine.",
                "Maintain low GI dietary habits.",
                "Repeat clinical assessment every 6 months."
            )
        )
    )

    fun getPredictionHistory(): List<PredictionResult> = mockHistory

    fun addPredictionResult(result: PredictionResult) {
        mockHistory.add(0, result)
    }

    fun getPersonalizedCarePlan(riskLevel: RiskLevel): CarePlan {
        return when (riskLevel) {
            RiskLevel.HEALTHY -> CarePlan(
                statusSummary = "Biomarkers, Foot & Retina scans show healthy physiological parameters.",
                riskLevel = RiskLevel.HEALTHY,
                dietPlan = listOf(
                    "Low Glycemic Index (GI) complex carbohydrates",
                    "High soluble fiber (35g/day from legumes, oats & chia seeds)",
                    "Lean protein sources & healthy Omega-3 fats",
                    "Limit refined sugars & processed sodium"
                ),
                exercisePlan = listOf(
                    "150 mins/week moderate aerobic activity (Brisk Walking, Swimming)",
                    "2 sessions/week resistance strength training",
                    "7-8 hours of restful sleep daily for optimal insulin sensitivity"
                ),
                lifestyleAdvice = listOf(
                    "Daily 10 min mindfulness meditation for stress control",
                    "Avoid prolonged sedentary sitting (> 45 mins continuous)"
                ),
                waterIntake = "2.8 Liters / Day",
                weightGoal = "65 kg (Maintain current BMI 22.4)",
                bloodSugarSchedule = listOf(
                    "Fasting check every Monday morning",
                    "2h Post-prandial check bi-weekly"
                ),
                medicationReminder = listOf(
                    "No prescription anti-diabetic medication required.",
                    "Daily Multivitamin & Vitamin D3 2000 IU supplement."
                ),
                footCareAdvice = listOf(
                    "Perform monthly AI foot ulcer upload check.",
                    "Keep feet clean, dry, and well moisturized."
                ),
                eyeCareAdvice = listOf(
                    "Annual dilated retinal examination.",
                    "Protect eyes from screen glare."
                ),
                emergencyWarnings = listOf(
                    "Seek immediate medical care if fasting glucose exceeds 250 mg/dL or if experiencing sudden blurred vision."
                ),
                doctorFollowUpSchedule = "Scheduled for Nov 15, 2026 (Annual Consult)",
                weeklyGoals = listOf("Log 10,000 steps for 5 consecutive days"),
                monthlyGoals = listOf("Complete full HbA1c & Lipid profile check")
            )
            RiskLevel.PREDIABETIC -> CarePlan(
                statusSummary = "Slightly elevated glucose / HbA1c. Reversible with targeted lifestyle intervention.",
                riskLevel = RiskLevel.PREDIABETIC,
                dietPlan = listOf(
                    "Strict carbohydrate counting (< 45g per meal)",
                    "Eliminate sugar-sweetened beverages entirely",
                    "Increase dietary fiber to 40g/day"
                ),
                exercisePlan = listOf(
                    "200 mins/week brisk cardio exercise",
                    "3 strength training sessions weekly"
                ),
                lifestyleAdvice = listOf("Target 5-7% weight reduction over 3 months"),
                waterIntake = "3.2 Liters / Day",
                weightGoal = "Reduce 4 kg in 60 days",
                bloodSugarSchedule = listOf("Check fasting glucose 3x per week"),
                medicationReminder = listOf("Metformin 500mg (as prescribed by physician)"),
                footCareAdvice = listOf("Daily visual inspection for pressure spots"),
                eyeCareAdvice = listOf("Bi-annual fundus scan"),
                emergencyWarnings = listOf("Alert doctor if glucose > 200 mg/dL twice in 24 hours"),
                doctorFollowUpSchedule = "Follow-up in 30 days",
                weeklyGoals = listOf("Zero refined sugar intake for 7 days"),
                monthlyGoals = listOf("Reduce fasting blood glucose below 100 mg/dL")
            )
            else -> CarePlan(
                statusSummary = "High Risk / Active Diabetic condition detected. Strict medical management required.",
                riskLevel = RiskLevel.DIABETIC,
                dietPlan = listOf("Endocrinologist-guided diabetic meal plan", "Ketone and carb monitoring"),
                exercisePlan = listOf("30 min low-impact walking post meals"),
                lifestyleAdvice = listOf("Continuous Glucose Monitoring (CGM) recommended"),
                waterIntake = "3.5 Liters / Day",
                weightGoal = "Active clinical weight management",
                bloodSugarSchedule = listOf("4x daily checks (Pre-meal & Bedtime)"),
                medicationReminder = listOf("Insulin / Oral Hypoglycemics as prescribed"),
                footCareAdvice = listOf("Daily podiatrist-approved nerve and foot check"),
                eyeCareAdvice = listOf("Quarterly ophthalmologist evaluation"),
                emergencyWarnings = listOf("IMMEDIATE EMERGENCY: Ketones in urine, extreme fatigue, vision loss"),
                doctorFollowUpSchedule = "Within 7 days with Primary Endocrinologist",
                weeklyGoals = listOf("Maintain 80% time-in-range (70-180 mg/dL)"),
                monthlyGoals = listOf("Lower HbA1c below 7.0%")
            )
        }
    }
}
