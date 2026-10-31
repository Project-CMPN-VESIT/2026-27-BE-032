import 'prediction_result.dart';

class CarePlan {
  final String statusSummary;
  final RiskLevel riskLevel;
  final List<String> dietPlan;
  final List<String> exercisePlan;
  final List<String> lifestyleAdvice;
  final String waterIntake;
  final String weightGoal;
  final List<String> bloodSugarSchedule;
  final List<String> medicationReminder;
  final List<String> footCareAdvice;
  final List<String> eyeCareAdvice;
  final List<String> emergencyWarnings;
  final String doctorFollowUpSchedule;
  final List<String> weeklyGoals;
  final List<String> monthlyGoals;

  CarePlan({
    required this.statusSummary,
    required this.riskLevel,
    required this.dietPlan,
    required this.exercisePlan,
    required this.lifestyleAdvice,
    required this.waterIntake,
    required this.weightGoal,
    required this.bloodSugarSchedule,
    required this.medicationReminder,
    required this.footCareAdvice,
    required this.eyeCareAdvice,
    required this.emergencyWarnings,
    required this.doctorFollowUpSchedule,
    required this.weeklyGoals,
    required this.monthlyGoals,
  });
}
