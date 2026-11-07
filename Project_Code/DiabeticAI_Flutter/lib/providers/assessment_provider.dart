import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prediction_result.dart';
import '../services/firestore_service.dart';

class AssessmentProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  PredictionResult? _latestResult;
  PredictionResult? _pendingResult;
  Map<String, dynamic>? _latestResponse;
  Map<String, dynamic>? _lastPayload;
  bool _isAnalyzing = false;

  PredictionResult? get latestResult => _latestResult;
  bool get isAnalyzing => _isAnalyzing;

  static double _numberValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  static int _intValue(Map<String, dynamic> data, String key, {int fallback = 0}) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static bool _boolValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static double calculateRuleBasedAssessmentScore(Map<String, dynamic> formData) {
    double score = 0.0;

    final bmi = _numberValue(formData, 'BMI');
    if (bmi >= 35) {
      score += 18.0;
    } else if (bmi >= 30) {
      score += 12.0;
    } else if (bmi >= 25) {
      score += 8.0;
    } else if (bmi >= 22) {
      score += 3.0;
    }

    final age = _intValue(formData, 'Age');
    if (age >= 11) {
      score += 16.0;
    } else if (age >= 8) {
      score += 10.0;
    } else if (age >= 6) {
      score += 6.0;
    }

    final familyHistory = _intValue(formData, 'FamilyHistory');
    final familyMembers = _intValue(formData, 'FamilyMembersCount');
    if (familyHistory > 0) {
      score += 10.0 + (familyMembers * 6.0);
    }

    if (_boolValue(formData, 'HighBP')) score += 15.0;
    if (_boolValue(formData, 'HighChol')) score += 12.0;
    if (_boolValue(formData, 'Stroke')) score += 14.0;
    if (_boolValue(formData, 'HeartDiseaseorAttack')) score += 14.0;
    if (_boolValue(formData, 'Smoker')) score += 14.0;
    if (_boolValue(formData, 'DiffWalk')) score += 12.0;

    final activity = _intValue(formData, 'PhysActivity', fallback: 2);
    if (activity <= 1) {
      score += 12.0;
    } else if (activity == 2) {
      score += 4.0;
    }

    final fruits = _intValue(formData, 'Fruits', fallback: 2);
    if (fruits <= 1) {
      score += 8.0;
    }

    final veggies = _intValue(formData, 'Veggies', fallback: 2);
    if (veggies == 0) {
      score += 8.0;
    } else if (veggies == 1) {
      score += 4.0;
    }

    final sleepValue = _intValue(formData, 'SleepDuration', fallback: 2);
    if (sleepValue == 1) {
      score += 7.0;
    } else if (sleepValue == 3) {
      score += 6.0;
    }

    final stress = _intValue(formData, 'StressLevel', fallback: 1);
    if (stress == 3) {
      score += 10.0;
    } else if (stress == 2) {
      score += 4.0;
    }

    final physicalHealth = _intValue(formData, 'PhysHlthRating', fallback: 1);
    if (physicalHealth >= 3) {
      score += 8.0 + ((physicalHealth - 2) * 5.0);
    }

    final mentalHealth = _intValue(formData, 'MentHlthRating', fallback: 1);
    if (mentalHealth >= 3) {
      score += 6.0 + ((mentalHealth - 2) * 4.0);
    }

    return score.clamp(0.0, 55.0);
  }

  static Map<String, dynamic> buildRuleBasedAssessmentResponse(
      Map<String, dynamic> formData) {
    final riskPercentage = calculateRuleBasedAssessmentScore(formData);
    final isGood = riskPercentage < 35.0;
    final riskLabel = isGood ? 'GOOD' : 'ABNORMAL';

    return {
      'success': true,
      'risk_percentage': riskPercentage,
      'risk_level': isGood ? 'healthy' : 'borderline',
      'prediction': isGood ? 'Good risk profile' : 'Abnormal risk profile',
      'status': riskLabel,
      'source': 'frontend-rule-engine',
      'confidence': null,
      'care_plan': isGood
          ? [
              'Maintain a balanced diet, regular activity, and preventive health checkups.',
              'Continue healthy sleep and stress management habits.',
            ]
          : [
              'Reduce sugar-sweetened drinks and refined carbohydrates.',
              'Increase fiber intake, physical activity, and monitoring of blood sugar trends.',
              'Review family history, stress, and routine preventive care with a clinician.',
            ],
      'class_probabilities': {
        'normal': isGood ? 100.0 - riskPercentage : 0.0,
        'borderline': null,
        'diabetes': null,
        'combined_prediabetes_diabetes': riskPercentage,
      },
    };
  }

  void reset() {
    _latestResult = null;
    _pendingResult = null;
    _latestResponse = null;
    _lastPayload = null;
    _isAnalyzing = false;
    notifyListeners();
  }

  double calculateBmi(double heightCm, double weightKg) {
    if (heightCm <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  Future<Map<String, dynamic>> runTabularAssessment(
      Map<String, dynamic> formData) async {
    if (_isAnalyzing) {
      throw StateError('An assessment is already being processed.');
    }
    if (_latestResult != null &&
        _latestResponse != null &&
        mapEquals(_lastPayload, formData)) {
      return _latestResponse!;
    }
    if (_lastPayload != null && !mapEquals(_lastPayload, formData)) {
      _latestResult = null;
    }

    _isAnalyzing = true;
    notifyListeners();
    try {
      final response = buildRuleBasedAssessmentResponse(formData);
      final riskValue = response['risk_percentage'];
      final prediction = response['prediction'];

      if (riskValue is! num ||
          !riskValue.isFinite ||
          riskValue < 0 ||
          riskValue > 100 ||
          prediction is! String ||
          prediction.trim().isEmpty) {
        throw const FormatException(
            'The local assessment rule engine returned an invalid result.');
      }

      final now = DateTime.now();
      final riskLevel = response['status'] == 'GOOD'
          ? RiskLevel.healthy
          : RiskLevel.prediabetic;
      final recommendations = response['care_plan'];
      final result = _pendingResult != null &&
              mapEquals(_lastPayload, formData)
          ? _pendingResult!
          : PredictionResult(
        id: now.microsecondsSinceEpoch.toString(),
        type: PredictionType.diabetesAssessment,
        title: 'Diabetes Risk Assessment',
        date:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        time:
            '${now.hour % 12 == 0 ? 12 : now.hour % 12}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}',
        createdAt: now,
        riskLevel: riskLevel,
        predictionLabel: prediction,
        riskPercentage: riskValue.toDouble(),
        confidencePercentage: null,
        assessmentScore: riskValue.toDouble(),
        recommendations: recommendations is Iterable
            ? recommendations.whereType<String>().toList()
            : const [],
        source: response['source'] as String? ?? 'frontend-rule-engine',
      );

      _pendingResult = result;
      _latestResponse = Map<String, dynamic>.from(response);
      _lastPayload = Map<String, dynamic>.from(formData);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        throw StateError('Sign in before saving an assessment.');
      }
      await _firestoreService.saveAssessmentAndPrediction(
        uid,
        formData,
        response,
        result,
      );

      _latestResult = result;
      _pendingResult = null;
      return _latestResponse!;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }
}
