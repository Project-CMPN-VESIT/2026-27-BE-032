import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prediction_result.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';

class AssessmentProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirestoreService _firestoreService = FirestoreService();
  PredictionResult? _latestResult;
  bool _isAnalyzing = false;

  PredictionResult? get latestResult => _latestResult;
  bool get isAnalyzing => _isAnalyzing;

  void reset() {
    _latestResult = null;
    _isAnalyzing = false;
    notifyListeners();
  }

  double calculateBmi(double heightCm, double weightKg) {
    if (heightCm <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  double calculateAssessmentRisk(Map<String, dynamic> data) {
    final age = (data['Age'] as num?)?.toInt() ?? 7;
    final bmi = (data['BMI'] as num?)?.toDouble() ?? 22;
    final familyHistory = (data['FamilyHistory'] as num?)?.toInt() ?? 0;
    final exercise = (data['ExerciseFrequency'] as num?)?.toInt() ??
        ((data['PhysActivity'] as num?)?.toInt() == 1 ? 3 : 0);
    final alcohol = (data['HvyAlcoholConsump'] as num?)?.toInt() ?? 0;

    var score = 0.0;
    score += age <= 2
        ? 2
        : age <= 4
            ? 5
            : age <= 6
                ? 10
                : age <= 8
                    ? 15
                    : 20;
    score += bmi < 25
        ? 3
        : bmi < 30
            ? 8
            : 15;
    score += familyHistory > 0 ? 10 : 0;
    score += (data['Smoker'] as num?)?.toInt() == 1 ? 8 : 0;
    score += alcohol == 1 ? 7 : 0;
    score += exercise >= 3
        ? -8
        : exercise > 0
            ? -3
            : 8;
    score += (data['HighBP'] as num?)?.toInt() == 1 ? 12 : 0;
    score += (data['HighChol'] as num?)?.toInt() == 1 ? 6 : 0;
    score += (data['Stroke'] as num?)?.toInt() == 1 ? 8 : 0;
    score += (data['HeartDiseaseorAttack'] as num?)?.toInt() == 1 ? 8 : 0;
    score += (data['DiffWalk'] as num?)?.toInt() == 1 ? 5 : 0;
    score += ((data['StressLevel'] as num?)?.toInt() ?? 1) >= 3 ? 4 : 0;
    score += ((data['JunkFood'] as num?)?.toInt() ?? 0) >= 2 ? 6 : 0;
    score += ((data['SugaryDrinks'] as num?)?.toInt() ?? 0) >= 1 ? 5 : 0;
    score += (data['SleepDuration'] == '<6 hrs') ? 5 : 0;
    score += ((data['PhysHlthRating'] as num?)?.toInt() ?? 1) >= 3 ? 4 : 0;
    score += ((data['MentHlthRating'] as num?)?.toInt() ?? 1) >= 3 ? 4 : 0;

    return (score / 115.0 * 100.0).clamp(0.0, 100.0);
  }

  Future<void> runTabularAssessment(Map<String, dynamic> formData) async {
    _isAnalyzing = true;
    notifyListeners();

    try {
      final response = await _apiService.predictDiabetes(formData);
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      if (authUid != null) {
        await _firestoreService.saveAssessmentRecord(
            authUid, formData, response);
      }

      final int target = (response['target'] as num?)?.toInt() ?? 0;
      final String label =
          response['prediction'] ?? 'Healthy - Low Risk Profile';
      final double riskPercentage =
          (response['risk_percentage'] as num?)?.toDouble() ?? 8.2;
      final double confidencePercentage =
          (response['confidence'] as num?)?.toDouble() ?? 95.5;

      RiskLevel riskLevel;
      List<String> recommendations;

      if (target == 2) {
        riskLevel = RiskLevel.diabetic;
        recommendations = [
          'Consult an endocrinologist for clinical HbA1c diagnostic testing.',
          'Adopt a targeted diabetic nutrition and continuous blood glucose monitor regimen.',
          'Schedule bi-annual retinal and foot neuropathy screenings.'
        ];
      } else if (target == 1) {
        riskLevel = RiskLevel.prediabetic;
        recommendations = [
          'Engage in 150+ minutes of moderate aerobic activity weekly.',
          'Reduce intake of refined carbohydrates and sugar-sweetened beverages.',
          'Target a 5-7% weight reduction to reverse prediabetic insulin resistance.'
        ];
      } else {
        riskLevel = RiskLevel.healthy;
        recommendations = [
          'Maintain daily physical activity and balanced soluble fiber-rich meals.',
          'Schedule annual routine health checkups.',
          'Continue healthy lifestyle habits to maintain optimal metabolic health.'
        ];
      }

      _latestResult = PredictionResult(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: PredictionType.diabetesAssessment,
        title: 'XGBoost 21-Feature Diabetes Screening',
        date: 'Just Now',
        riskLevel: riskLevel,
        predictionLabel: label,
        riskPercentage: riskPercentage,
        confidencePercentage: confidencePercentage,
        recommendations: recommendations,
      );
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }
}
