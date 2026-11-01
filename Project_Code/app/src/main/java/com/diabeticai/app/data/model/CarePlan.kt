package com.diabeticai.app.data.model

data class CarePlan(
    val statusSummary: String,
    val riskLevel: RiskLevel,
    val dietPlan: List<String>,
    val exercisePlan: List<String>,
    val lifestyleAdvice: List<String>,
    val waterIntake: String,
    val weightGoal: String,
    val bloodSugarSchedule: List<String>,
    val medicationReminder: List<String>,
    val footCareAdvice: List<String>,
    val eyeCareAdvice: List<String>,
    val emergencyWarnings: List<String>,
    val doctorFollowUpSchedule: String,
    val weeklyGoals: List<String>,
    val monthlyGoals: List<String>
)
