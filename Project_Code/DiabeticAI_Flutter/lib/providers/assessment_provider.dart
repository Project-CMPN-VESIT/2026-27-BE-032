import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prediction_result.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';

class AssessmentProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirestoreService _firestoreService = FirestoreService();
  PredictionResult? _latestResult;
  PredictionResult? _pendingResult;
  Map<String, dynamic>? _latestResponse;
  Map<String, dynamic>? _lastPayload;
  bool _isAnalyzing = false;

  PredictionResult? get latestResult => _latestResult;
  bool get isAnalyzing => _isAnalyzing;

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
      final response = _pendingResult != null &&
              mapEquals(_lastPayload, formData) &&
              _latestResponse != null
          ? _latestResponse!
          : await _apiService.predictDiabetes(formData);
      final riskValue = response['risk_percentage'];
      final prediction = response['prediction'];
      if (response['success'] != true ||
          riskValue is! num ||
          !riskValue.isFinite ||
          riskValue < 0 ||
          riskValue > 100 ||
          prediction is! String ||
          prediction.trim().isEmpty) {
        throw const FormatException(
            'Assessment API response is missing a valid prediction.');
      }

      final now = DateTime.now();
      final riskLevel = switch (response['risk_level']) {
        'healthy' => RiskLevel.healthy,
        'borderline' => RiskLevel.borderline,
        'prediabetic' => RiskLevel.prediabetic,
        'diabetic' => RiskLevel.diabetic,
        'highRisk' => RiskLevel.highRisk,
        _ => RiskLevel.inconclusive,
      };
      final confidence = response['confidence'];
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
        confidencePercentage: confidence is num &&
                confidence.isFinite &&
                confidence >= 0 &&
                confidence <= 100
            ? confidence.toDouble()
            : null,
        assessmentScore: riskValue.toDouble(),
        recommendations: recommendations is Iterable
            ? recommendations.whereType<String>().toList()
            : const [],
        source: response['source'] is String
            ? response['source'] as String
            : 'backend',
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
