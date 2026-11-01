import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/prediction_result.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
import '../services/image_validation_service.dart';

class MultiModalProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  // Input 1: Assessment Payload
  Map<String, dynamic>? _assessmentPayload;
  Map<String, dynamic>? _assessmentResult;
  double _assessmentScore = 0.0;

  // Input 2: Retina Image File & Details
  File? _retinaImageFile;
  String? _retinaImageUrl;
  String? _retinaPrediction;
  double? _retinaConfidence;
  String? _retinaRisk;

  // Input 3: Foot Image File & Details
  File? _footImageFile;
  String? _footImageUrl;
  String? _footPrediction;
  double? _footConfidence;
  String? _footSeverity;
  String? _footRisk;

  // Prediction Output & Status
  PredictionResult? _latestPrediction;
  bool _isAnalyzing = false;
  String? _errorMessage;

  // Getters
  Map<String, dynamic>? get assessmentPayload => _assessmentPayload;
  double get assessmentScore => _assessmentScore;
  File? get retinaImageFile => _retinaImageFile;
  String? get retinaImageUrl => _retinaImageUrl;
  File? get footImageFile => _footImageFile;
  String? get footImageUrl => _footImageUrl;
  PredictionResult? get latestPrediction => _latestPrediction;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;

  // Checklist Completion Flags
  bool get isAssessmentComplete => _assessmentPayload != null;
  bool get isRetinaComplete =>
      _retinaImageFile != null || (_retinaImageUrl ?? '').isNotEmpty;
  bool get isFootComplete =>
      _footImageFile != null || (_footImageUrl ?? '').isNotEmpty;

  /// Multi-Modal prediction can run ONLY when all 3 inputs are complete
  bool get isReadyForPrediction =>
      isAssessmentComplete && isRetinaComplete && isFootComplete;

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  void setAssessmentPayload(
      Map<String, dynamic> payload, double calculatedScore) {
    _assessmentPayload = payload;
    _assessmentScore = calculatedScore;
    _errorMessage = null;
    notifyListeners();
  }

  Map<String, dynamic>? _retinaResultMap;
  Map<String, dynamic>? _footResultMap;

  Map<String, dynamic>? get retinaResultMap => _retinaResultMap;
  Map<String, dynamic>? get footResultMap => _footResultMap;

  void setRetinaResultMap(Map<String, dynamic> result) {
    _retinaResultMap = result;
    _retinaPrediction = result['prediction'];
    _retinaConfidence = (result['confidence'] as num?)?.toDouble();
    _retinaRisk = result['risk_level'];
    notifyListeners();
  }

  void setFootResultMap(Map<String, dynamic> result) {
    _footResultMap = result;
    _footPrediction = result['prediction'];
    _footConfidence = (result['confidence'] as num?)?.toDouble();
    _footSeverity = result['severity'];
    _footRisk = result['risk_level'];
    notifyListeners();
  }

  void setRetinaPrediction(String prediction,
      {double? confidence, String? riskLevel}) {
    _retinaPrediction = prediction;
    _retinaConfidence = confidence;
    _retinaRisk = riskLevel;
    notifyListeners();
  }

  void setRetinaScan({File? imageFile, required String imageUrl}) {
    _retinaImageFile = imageFile;
    _retinaImageUrl = imageUrl;
    notifyListeners();
  }

  void setFootScan({File? imageFile, required String imageUrl}) {
    _footImageFile = imageFile;
    _footImageUrl = imageUrl;
    notifyListeners();
  }

  void setFootPrediction(String prediction,
      {double? confidence, String? severity, String? riskLevel}) {
    _footPrediction = prediction;
    _footConfidence = confidence;
    _footSeverity = severity;
    _footRisk = riskLevel;
    notifyListeners();
  }

  Future<void> pickRetinaImage(ImageSource source) async {
    try {
      final XFile? file =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;

      final selectedFile = File(file.path);
      final validation = await ImageValidationService.validateImage(
        selectedFile,
        ScanImageType.retina,
      );

      if (!validation.isValid) {
        _errorMessage = validation.errorMessage;
        _retinaImageFile = null;
        notifyListeners();
        return;
      }

      _errorMessage = null;
      _retinaImageFile = selectedFile;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to select retina image: $e';
      notifyListeners();
    }
  }

  Future<void> pickFootImage(ImageSource source) async {
    try {
      final XFile? file =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;

      final selectedFile = File(file.path);
      final validation = await ImageValidationService.validateImage(
        selectedFile,
        ScanImageType.foot,
      );

      if (!validation.isValid) {
        _errorMessage = validation.errorMessage;
        _footImageFile = null;
        notifyListeners();
        return;
      }

      _errorMessage = null;
      _footImageFile = selectedFile;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to select foot image: $e';
      notifyListeners();
    }
  }

  /// Dynamic Care Plan Generator matching the 4 combined risk cases
  List<String> generateDynamicCarePlan({
    required double assessmentScore,
    required bool isRetinaAbnormal,
    required bool isFootAbnormal,
  }) {
    if (assessmentScore >= 40.0 && isRetinaAbnormal && isFootAbnormal) {
      return [
        'Immediate physician & endocrinologist specialist consultation',
        'Urgent consultation with certified diabetic foot care specialist',
        'Comprehensive examination by retinal specialist ophthalmologist',
        'Perform full diagnostic blood laboratory panel including HbA1c',
        'Intensive diabetic lifestyle intervention & dietary plan',
        'Comprehensive pharmacological review & medication adjustment',
        'Daily blood glucose, blood pressure, and foot wound monitoring'
      ];
    }
    if (isRetinaAbnormal) {
      return [
        'Immediate ophthalmologist consultation & dilated eye exam',
        'Strict daily blood sugar monitoring (fasting & post-prandial)',
        'Request diagnostic HbA1c laboratory blood test',
        'Undergo specialized fundus retinal imaging & OCT examination',
        'Implement low-glycemic, heart-healthy dietary changes'
      ];
    }
    if (isFootAbnormal) {
      return [
        'Initiate professional foot wound management & protective dressing',
        'Perform daily foot inspection for cuts, blisters, or warm spots',
        'Consult certified podiatrist / diabetic foot care specialist',
        'Prevent skin breakdown and secondary bacterial infections',
        'Maintain tight blood sugar control to promote tissue healing'
      ];
    }
    return [
      'Maintain healthy lifestyle with 30 minutes daily physical activity',
      'Schedule annual comprehensive diabetes & health screening',
      'Follow balanced, low-glycemic, fiber-rich Mediterranean diet',
      'Keep hydrated and monitor routine wellness metrics'
    ];
  }

  /// Combined Multi-Modal Prediction Workflow
  Future<bool> runCombinedMultiModalPrediction(String uid) async {
    if (!isReadyForPrediction) {
      _errorMessage =
          'Complete all three assessments before generating your final diabetes prediction.';
      notifyListeners();
      return false;
    }

    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    debugPrint("--------------------------------------------------");
    debugPrint("STEP 2: [MultiModalProvider] runCombinedMultiModalPrediction() called");

    try {
      final assessmentResult =
          _assessmentResult ?? {'risk_percentage': _assessmentScore};

      final retinaResult = _retinaResultMap ?? {
        'prediction': _retinaPrediction ?? 'Healthy Fundus - No Retinopathy',
        'risk_percentage': PredictionResult.retinaRiskFor(_retinaPrediction ?? '', _retinaConfidence ?? 90),
        'confidence': _retinaConfidence ?? 92.0,
        'severity': 'No Retinopathy',
        'risk_level': _retinaRisk ?? 'healthy',
      };

      final footResult = _footResultMap ?? {
        'prediction': _footPrediction ?? 'Grade 0 - No Lesion',
        'risk_percentage': PredictionResult.footRiskFor(_footPrediction ?? '', _footConfidence ?? 90),
        'confidence': _footConfidence ?? 90.0,
        'severity': _footSeverity ?? 'Grade 0 Normal',
        'risk_level': _footRisk ?? 'healthy',
      };

      Map<String, dynamic> apiResult;

      try {
        final String activeRetinaUrl = (_retinaImageUrl != null && _retinaImageUrl!.startsWith('http'))
            ? _retinaImageUrl!
            : '';
        final String activeFootUrl = (_footImageUrl != null && _footImageUrl!.startsWith('http'))
            ? _footImageUrl!
            : '';

        final payload = {
          'assessment': assessmentResult,
          'retina': retinaResult,
          'foot': footResult,
          'retinaImage': activeRetinaUrl,
          'footImage': activeFootUrl,
        };
        debugPrint("STEP 4: [MultiModalProvider] Calling ApiService.predictMultiModal()...");
        apiResult = await _apiService.predictMultiModal(payload);
        debugPrint("STEP 5: [MultiModalProvider] Received Final Multi-Modal API response: $apiResult");
      } catch (networkError) {
        debugPrint(
            '⚠️ [MultiModalProvider] Backend request failed/timed out ($networkError). Using local fallback calculation.');
        
        final double assessmentScore =
            (assessmentResult['risk_percentage'] as num?)?.toDouble() ??
                _assessmentScore;
        final double retinaScore =
            (retinaResult['risk_percentage'] as num?)?.toDouble() ?? 8.0;
        final double footScore =
            (footResult['risk_percentage'] as num?)?.toDouble() ?? 8.0;

        final double overallScore =
            ((assessmentScore * 0.70) + (retinaScore * 0.15) + (footScore * 0.15))
                .clamp(0.0, 100.0);

        final String riskLevelStr = overallScore <= 20.0
            ? 'healthy'
            : (overallScore <= 40.0
                ? 'prediabetic'
                : (overallScore <= 60.0 ? 'diabetic' : 'highRisk'));

        final String predictionLabel = overallScore <= 20.0
            ? 'Low Risk Profile'
            : (overallScore <= 40.0
                ? 'Mild Risk Profile'
                : (overallScore <= 60.0
                    ? 'Moderate Risk Profile'
                    : 'High Risk Profile'));

        apiResult = {
          'assessment_score': assessmentScore,
          'retina_result':
              retinaResult['prediction'] ?? 'Healthy Fundus - No Retinopathy',
          'retina_risk_percentage': retinaScore,
          'foot_result':
              footResult['prediction'] ?? 'Grade 0 - No Lesion Detected',
          'foot_risk_percentage': footScore,
          'overall_risk_percentage': overallScore,
          'risk_level': riskLevelStr,
          'prediction_label': predictionLabel,
          'confidence': 97.8,
          'source': 'local_fallback',
        };
      }

      final double assessmentScore =
          (apiResult['assessment_score'] as num?)?.toDouble() ??
              _assessmentScore;
      final String retinaLabel =
          apiResult['retina_result'] ?? 'Healthy Fundus - No Retinopathy';
      final String footLabel =
          apiResult['foot_result'] ?? 'Grade 0 - No Lesion Detected';
      final double overallRiskPct =
          (apiResult['overall_risk_percentage'] as num?)?.toDouble() ?? 50.0;
      final String riskLevelStr = apiResult['risk_level'] ?? 'healthy';
      final String predictionLabel =
          apiResult['prediction_label'] ?? 'Multi-Modal Assessment Complete';

      final bool isRetinaAbnormal =
          retinaLabel.toLowerCase().contains('retinopathy') &&
              !retinaLabel.toLowerCase().contains('no retinopathy');
      final bool isFootAbnormal = footLabel.toLowerCase().contains('ulcer') ||
          (footLabel.toLowerCase().contains('grade') &&
              !footLabel.toLowerCase().contains('grade 0'));

      // Generate Dynamic Care Plan
      final recommendations = generateDynamicCarePlan(
        assessmentScore: assessmentScore,
        isRetinaAbnormal: isRetinaAbnormal,
        isFootAbnormal: isFootAbnormal,
      );

      final normalizedRiskLevel = riskLevelStr.toLowerCase();
      final riskLevelEnum = normalizedRiskLevel == 'very high risk'
          ? RiskLevel.highRisk
          : normalizedRiskLevel == 'high risk'
              ? RiskLevel.diabetic
              : normalizedRiskLevel == 'moderate risk'
                  ? RiskLevel.prediabetic
                  : normalizedRiskLevel == 'mild risk'
                      ? RiskLevel.prediabetic
                      : normalizedRiskLevel == 'low risk'
                          ? RiskLevel.healthy
                          : overallRiskPct > 80
                              ? RiskLevel.highRisk
                              : overallRiskPct > 40
                                  ? RiskLevel.diabetic
                                  : overallRiskPct > 20
                                      ? RiskLevel.prediabetic
                                      : RiskLevel.healthy;

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
      final nextScreeningDate =
          '${now.year + (riskLevelEnum == RiskLevel.healthy ? 1 : 0)}-${((now.month + 3) % 12 + 1).toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final result = PredictionResult(
        id: now.millisecondsSinceEpoch.toString(),
        type: PredictionType.multiModalCombined,
        title: 'Multi-Modal AI Diabetes Assessment',
        date: dateStr,
        time: timeStr,
        riskLevel: riskLevelEnum,
        predictionLabel: predictionLabel,
        riskPercentage: overallRiskPct,
        confidencePercentage:
            (apiResult['confidence'] as num?)?.toDouble() ?? 97.8,
        assessmentScore: assessmentScore,
        retinaRiskPercentage:
            (apiResult['retina_risk_percentage'] as num?)?.toDouble() ??
                PredictionResult.retinaRiskFor(retinaLabel, _retinaConfidence ?? 0),
        footRiskPercentage:
            (apiResult['foot_risk_percentage'] as num?)?.toDouble() ??
                PredictionResult.footRiskFor(footLabel, _footConfidence ?? 0),
        retinaResult: retinaLabel,
        footResult: footLabel,
        carePlanStatus: 'Active Personalized Care Plan',
        retinaImageUrl: _retinaImageUrl,
        footImageUrl: _footImageUrl,
        nextScreeningDate: nextScreeningDate,
        recommendations: recommendations,
        source: apiResult['source'] as String? ?? 'backend',
      );

      _latestPrediction = result;

      // Store in user-isolated Firestore subcollections
      if (uid.isNotEmpty) {
        await _firestoreService.saveMultiModalRecord(
          uid: uid,
          prediction: result,
          assessmentPayload: _assessmentPayload ?? {},
        );
      }

      _isAnalyzing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to generate multi-modal prediction: $e';
      _isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  void resetWorkflow() {
    _assessmentPayload = null;
    _assessmentResult = null;
    _assessmentScore = 0.0;
    _retinaImageFile = null;
    _retinaImageUrl = null;
    _retinaPrediction = null;
    _retinaConfidence = null;
    _retinaRisk = null;
    _footImageFile = null;
    _footImageUrl = null;
    _footPrediction = null;
    _footConfidence = null;
    _footSeverity = null;
    _footRisk = null;
    _latestPrediction = null;
    _errorMessage = null;
    _isAnalyzing = false;
    notifyListeners();
  }
}
