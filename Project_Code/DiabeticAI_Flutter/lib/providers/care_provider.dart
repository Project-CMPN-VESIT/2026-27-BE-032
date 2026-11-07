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
          statusSummary:
              'Biomarkers, Foot & Retina scans show healthy physiological parameters.',
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
          statusSummary:
              'Slightly elevated glucose / HbA1c. Reversible with targeted lifestyle intervention.',
          riskLevel: RiskLevel.prediabetic,
          dietPlan: [
            'Strict carb control (< 45g/meal)',
            'Eliminate sugary drinks'
          ],
          exercisePlan: [
            '200 mins/week cardio exercise',
            '3 strength training sessions'
          ],
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
      case RiskLevel.borderline:
        return CarePlan(
          statusSummary:
              'Multimodal screening indicates borderline risk. Comprehensive lifestyle changes, glucose tracking, and medical consultation recommended.',
          riskLevel: RiskLevel.borderline,
          dietPlan: [
            'Structured dietary portion control with low-glycemic index meal planning',
            'Eliminate sugar-sweetened beverages & refined carbohydrates',
            'Increase soluble dietary fiber (oats, legumes, chia seeds, vegetables) to 35g/day',
            'Prioritize lean proteins and heart-healthy unsaturated fats',
          ],
          exercisePlan: [
            '150-180 mins/week moderate aerobic exercise (brisk walking, cycling)',
            '2-3 resistance strength training sessions per week',
            '30 min low-impact walk post-meals to blunt glucose spikes',
          ],
          lifestyleAdvice: [
            'Target 5% gradual weight reduction over 90 days',
            'Maintain structured daily blood glucose & blood pressure logs',
            'Prioritize 7-8 hours of quality sleep to improve insulin sensitivity',
          ],
          waterIntake: '3.0 Liters / Day',
          weightGoal: '5% reduction in 90 days',
          bloodSugarSchedule: [
            'Fasting glucose check 2-3x per week',
            '2-hour post-prandial glucose check once weekly',
          ],
          medicationReminder: [
            'Consult your clinician for formal diagnostic evaluation (HbA1c & fasting glucose)',
            'Do not self-prescribe medications without physician guidance',
          ],
          footCareAdvice: [
            'Daily visual foot check for redness, blisters, or calluses',
            'Keep feet clean, dry, and wear comfortable supportive shoes',
          ],
          eyeCareAdvice: [
            'Comprehensive dilated retinal examination within 6 months',
            'Monitor for visual blurriness or floaters',
          ],
          emergencyWarnings: [
            'Consult doctor if fasting glucose exceeds 180 mg/dL or if persistent foot numbness/pain occurs',
          ],
          doctorFollowUpSchedule:
              'Schedule physician follow-up within 30 days for laboratory HbA1c testing',
          weeklyGoals: [
            'Complete 150 minutes of aerobic exercise',
            'Maintain zero refined sugars for 6 out of 7 days',
          ],
          monthlyGoals: [
            'Schedule laboratory diagnostic HbA1c test',
            'Maintain stable healthy blood pressure (< 125/80 mmHg)',
          ],
        );
      case RiskLevel.inconclusive:
        return CarePlan(
          statusSummary:
              'The scan could not determine lesion status conclusively. Clinical review is recommended.',
          riskLevel: RiskLevel.inconclusive,
          dietPlan: ['Continue your clinician-guided diabetes meal plan.'],
          exercisePlan: [
            'Avoid excessive pressure on a painful or visibly damaged foot.'
          ],
          lifestyleAdvice: ['Do not use screening alone to rule out a diabetic complication.'],
          waterIntake: 'Follow your clinician guidance',
          weightGoal: 'Not assessed by screening',
          bloodSugarSchedule: [
            'Continue your existing glucose monitoring schedule.'
          ],
          medicationReminder: [
            'Do not change medication based on this screening scan.'
          ],
          footCareAdvice: [
            'Have any visible wound assessed promptly by a qualified clinician.'
          ],
          eyeCareAdvice: ['Continue routine dilated eye screening.'],
          emergencyWarnings: [
            'Seek urgent care for a worsening wound, fever, or signs of infection.'
          ],
          doctorFollowUpSchedule: 'Arrange clinical review for any visible wounds or symptoms.',
          weeklyGoals: [],
          monthlyGoals: [],
        );
      case RiskLevel.highRisk:
      case RiskLevel.diabetic:
        return CarePlan(
          statusSummary:
              'High Risk / Possible Diabetes indicated by multimodal screening. Urgent physician consultation, formal diagnostic testing, and specialized care required.',
          riskLevel: RiskLevel.highRisk,
          dietPlan: [
            'Clinically supervised medical nutrition therapy',
            'Strict carbohydrate restriction (< 35g/meal)',
            'Eliminate all refined sugars, sweetened beverages, and ultra-processed foods',
            'Emphasize high-soluble fiber and antioxidant-rich vegetables',
          ],
          exercisePlan: [
            'Low-impact 20-30 min daily walking post-meals under clinician guidance',
            'Avoid strenuous weightlifting until cardiovascular and retinal clearance is obtained',
            'Break up prolonged sitting every 30 minutes',
          ],
          lifestyleAdvice: [
            'Continuous or 4x daily capillary blood glucose monitoring',
            'Strict cardiovascular risk reduction (blood pressure & cholesterol control)',
            'Complete cessation of smoking and alcohol consumption',
          ],
          waterIntake: '3.5 Liters / Day',
          weightGoal: 'Clinical weight management under physician supervision',
          bloodSugarSchedule: [
            '4x daily checks (Fasting, Pre-meal, 2h Post-prandial & Bedtime)',
          ],
          medicationReminder: [
            'Immediate physician evaluation for antidiabetic pharmacological therapy',
            'Take prescribed medications strictly as directed by your clinician',
          ],
          footCareAdvice: [
            'Immediate consultation with a certified podiatrist / diabetic foot care specialist',
            'Daily visual foot inspection with a mirror for cuts, ulcers, or hot spots',
            'Wear approved diabetic socks and offloading orthopedic footwear',
          ],
          eyeCareAdvice: [
            'Urgent dilated eye examination by a retinal specialist ophthalmologist',
            'Optical coherence tomography (OCT) imaging to check for macular edema',
          ],
          emergencyWarnings: [
            'IMMEDIATE EMERGENCY: Seek acute emergency medical care if fasting glucose > 250 mg/dL, ketones are present, or sudden visual disturbances occur.',
          ],
          doctorFollowUpSchedule: 'Urgent consultation with physician / endocrinologist within 7 days',
          weeklyGoals: ['Achieve 70%+ glucose time-in-range (70-180 mg/dL)', 'Daily foot and eye inspection logs'],
          monthlyGoals: ['Target HbA1c reduction towards < 7.0% under physician supervision'],
        );
    }
  }

  void updateFromPrediction(PredictionResult result) {
    final base = getCarePlanForLevel(result.riskLevel);

    final bool isEyeAbnormal = result.retinaStatusLabel != 'NORMAL' && result.retinaStatusLabel.isNotEmpty;
    final bool isFootAbnormal = result.footStatusLabel != 'NORMAL' && result.footStatusLabel.isNotEmpty && result.footStatusLabel != 'INCONCLUSIVE';

    List<String> eyeCare = List.from(base.eyeCareAdvice);
    if (isEyeAbnormal) {
      eyeCare = [
        'Urgent comprehensive dilated eye examination by a retinal specialist ophthalmologist for detected retinopathy.',
        'Undergo optical coherence tomography (OCT) imaging to evaluate retinal microvasculature.',
        'Strict blood pressure & glycemic control to prevent diabetic retinopathy progression.',
        'Avoid high-intensity straining that could increase intraocular retinal pressure.',
      ];
    }

    List<String> footCare = List.from(base.footCareAdvice);
    if (isFootAbnormal) {
      footCare = [
        'Immediate consultation with a certified podiatrist or diabetic foot care specialist for detected ulcer/lesion.',
        'Professional wound management: initiate protective non-adherent dressing and pressure offloading footwear.',
        'Perform daily visual foot inspections for cuts, blisters, erythema, swelling, or localized temperature changes.',
        'Strict infection prevention: keep ulcerated site clean and dry; avoid walking barefoot or wearing tight footwear.',
      ];
    }

    String summary = base.statusSummary;
    if (result.predictionLabel.isNotEmpty) {
      final scoreStr = result.riskPercentage != null ? ' (${result.riskPercentage!.toStringAsFixed(1)}% Overall Demo Risk Score)' : '';
      summary = 'Overall Screening: ${result.predictionLabel}$scoreStr. ${base.statusSummary}';
    }

    _currentCarePlan = CarePlan(
      statusSummary: summary,
      riskLevel: result.riskLevel,
      dietPlan: base.dietPlan,
      exercisePlan: base.exercisePlan,
      lifestyleAdvice: base.lifestyleAdvice,
      waterIntake: base.waterIntake,
      weightGoal: base.weightGoal,
      bloodSugarSchedule: base.bloodSugarSchedule,
      medicationReminder: base.medicationReminder,
      footCareAdvice: footCare,
      eyeCareAdvice: eyeCare,
      emergencyWarnings: base.emergencyWarnings,
      doctorFollowUpSchedule: base.doctorFollowUpSchedule,
      weeklyGoals: base.weeklyGoals,
      monthlyGoals: base.monthlyGoals,
    );
    notifyListeners();
  }
}
