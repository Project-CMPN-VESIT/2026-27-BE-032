import 'package:flutter/material.dart';
import '../models/care_plan.dart';
import '../models/prediction_result.dart';

class CareProvider with ChangeNotifier {
  late CarePlan _currentCarePlan;

  CarePlan get currentCarePlan => _currentCarePlan;

  CareProvider() {
    _currentCarePlan = getCarePlanForLevel(RiskLevel.healthy);
  }

  CarePlan getCarePlanForLevel(RiskLevel level) {
    switch (level) {
      case RiskLevel.healthy:
        return CarePlan(
          statusSummary: 'Biomarkers, Foot & Retina scans show healthy physiological parameters.',
          riskLevel: RiskLevel.healthy,
          dietPlan: [
            'Low Glycemic Index (GI) complex carbohydrates',
            'High soluble fiber (35g/day from legumes, oats & chia seeds)',
            'Lean protein sources & healthy Omega-3 fats',
            'Limit refined sugars & processed sodium'
          ],
          exercisePlan: [
            '150 mins/week moderate aerobic activity (Brisk Walking, Swimming)',
            '2 sessions/week resistance strength training',
            '7-8 hours of restful sleep daily for optimal insulin sensitivity'
          ],
          lifestyleAdvice: [
            'Daily 10 min mindfulness meditation for stress control',
            'Avoid prolonged sedentary sitting (> 45 mins continuous)'
          ],
          waterIntake: '2.8 Liters / Day',
          weightGoal: '65 kg (Maintain current BMI 22.4)',
          bloodSugarSchedule: [
            'Fasting check every Monday morning',
            '2h Post-prandial check bi-weekly'
          ],
          medicationReminder: [
            'No prescription anti-diabetic medication required.',
            'Daily Multivitamin & Vitamin D3 2000 IU supplement.'
          ],
          footCareAdvice: [
            'Perform monthly AI foot ulcer upload check.',
            'Keep feet clean, dry, and well moisturized.'
          ],
          eyeCareAdvice: [
            'Annual dilated retinal examination.',
            'Protect eyes from screen glare.'
          ],
          emergencyWarnings: [
            'Seek immediate medical care if fasting glucose exceeds 250 mg/dL or if experiencing sudden blurred vision.'
          ],
          doctorFollowUpSchedule: 'Scheduled for Nov 15, 2026 (Annual Consult)',
          weeklyGoals: ['Log 10,000 steps for 5 consecutive days'],
          monthlyGoals: ['Complete full HbA1c & Lipid profile check'],
        );
      case RiskLevel.prediabetic:
        return CarePlan(
          statusSummary: 'Slightly elevated glucose / HbA1c. Reversible with targeted lifestyle intervention.',
          riskLevel: RiskLevel.prediabetic,
          dietPlan: ['Strict carb control (< 45g/meal)', 'Eliminate sugary drinks'],
          exercisePlan: ['200 mins/week cardio exercise', '3 strength training sessions'],
          lifestyleAdvice: ['Target 5-7% weight reduction'],
          waterIntake: '3.2 Liters / Day',
          weightGoal: 'Reduce 4 kg in 60 days',
          bloodSugarSchedule: ['Check fasting glucose 3x per week'],
          medicationReminder: ['Metformin 500mg (as prescribed)'],
          footCareAdvice: ['Daily visual inspection'],
          eyeCareAdvice: ['Bi-annual fundus scan'],
          emergencyWarnings: ['Alert doctor if glucose > 200 mg/dL'],
          doctorFollowUpSchedule: 'Follow-up in 30 days',
          weeklyGoals: ['Zero refined sugar for 7 days'],
          monthlyGoals: ['Fasting glucose < 100 mg/dL'],
        );
      default:
        return CarePlan(
          statusSummary: 'High Risk / Active Diabetic condition detected.',
          riskLevel: RiskLevel.diabetic,
          dietPlan: ['Endocrinologist guided meal plan'],
          exercisePlan: ['30 min low impact walk post meals'],
          lifestyleAdvice: ['Continuous glucose monitoring recommended'],
          waterIntake: '3.5 Liters / Day',
          weightGoal: 'Clinical weight management',
          bloodSugarSchedule: ['4x daily checks (Pre-meal & Bedtime)'],
          medicationReminder: ['Insulin / Oral meds as prescribed'],
          footCareAdvice: ['Daily podiatrist-approved foot check'],
          eyeCareAdvice: ['Quarterly ophthalmologist evaluation'],
          emergencyWarnings: ['IMMEDIATE EMERGENCY: Vision loss or extreme fatigue'],
          doctorFollowUpSchedule: 'Within 7 days',
          weeklyGoals: ['80% time-in-range (70-180 mg/dL)'],
          monthlyGoals: ['HbA1c < 7.0%'],
        );
    }
  }
}
