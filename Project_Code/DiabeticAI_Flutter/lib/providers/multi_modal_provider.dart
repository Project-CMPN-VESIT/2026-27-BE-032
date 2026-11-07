import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/prediction_result.dart';
import '../services/firestore_service.dart';
import '../services/image_validation_service.dart';

double? _validRiskPercentage(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 100) {
    return null;
  }
  return value.toDouble();
}

class MultiModalProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  static Map<String, dynamic> calculateFrontendFusion({
    required double assessmentScore,
    required bool retinaAbnormal,
    required bool footAbnormal,
  }) {
    final assessmentStatus = assessmentScore < 35.0 ? 'GOOD' : 'ABNORMAL';
    final abnormalCount = [assessmentStatus == 'ABNORMAL', retinaAbnormal, footAbnormal]
        .where((value) => value)
        .length;

    if (assessmentStatus == 'GOOD' && !retinaAbnormal && !footAbnormal) {
      return {
        'predictionLabel': 'Healthy / Normal',
        'riskPercentage': 5.0,
        'riskLevel': 'healthy',
      };
    }

    final riskScore = switch (abnormalCount) {
      0 => 5.0,
      1 => 20.0,
      2 => 45.0,
      _ => 72.0,
    };

    final predictionLabel = switch (abnormalCount) {
      0 => 'Healthy / Normal',
      1 => 'Prediabetic / Early Risk',
      2 => 'Borderline',
      _ => 'Diabetic / High Risk',
    };

    final riskLevel = switch (abnormalCount) {
      0 => 'healthy',
      1 => 'prediabetic',
      2 => 'borderline',
      _ => 'highRisk',
    };

    return {
      'predictionLabel': predictionLabel,
      'riskPercentage': riskScore,
      'riskLevel': riskLevel,
      'assessmentStatus': assessmentStatus,
      'retinaAbnormal': retinaAbnormal,
      'footAbnormal': footAbnormal,
      'abnormalCount': abnormalCount,
    };
  }

  // Input 1: Assessment Payload
  Map<String, dynamic>? _assessmentPayload;
  Map<String, dynamic>? _assessmentResult;
  double? _assessmentScore;

  // Input 2: Retina Image File & Details
  File? _retinaImageFile;
  String? _retinaImageUrl;

  // Input 3: Foot Image File & Details
  File? _footImageFile;
  String? _footImageUrl;

  // Prediction Output & Status
  PredictionResult? _latestPrediction;
  PredictionResult? _pendingPrediction;
  String? _pendingUid;
  String? _predictionOwnerUid;
  String? _currentPredictionSignature;
  bool _isAnalyzing = false;
  String? _errorMessage;

  // Getters
  Map<String, dynamic>? get assessmentPayload => _assessmentPayload;
  double? get assessmentScore => _assessmentScore;
  File? get retinaImageFile => _retinaImageFile;
  String? get retinaImageUrl => _retinaImageUrl;
  File? get footImageFile => _footImageFile;
  String? get footImageUrl => _footImageUrl;
  PredictionResult? get latestPrediction => _latestPrediction;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;

  // Checklist Completion Flags
  bool get isAssessmentComplete =>
      _assessmentPayload != null && _assessmentResult != null;
  bool get isRetinaComplete =>
      (_retinaImageFile != null || (_retinaImageUrl ?? '').isNotEmpty) &&
      _retinaResultMap != null;
  bool get isFootComplete =>
      (_footImageFile != null || (_footImageUrl ?? '').isNotEmpty) &&
      _footResultMap != null;

  /// Multi-Modal prediction can run ONLY when all 3 inputs are complete
  bool get isReadyForPrediction =>
      isAssessmentComplete && isRetinaComplete && isFootComplete;

  Future<void> loadLatestPredictionForUser(String uid) async {
    if (uid.isEmpty) return;
    if (_predictionOwnerUid != uid) {
      _predictionOwnerUid = uid;
      _latestPrediction = null;
      _pendingPrediction = null;
      _pendingUid = null;
      notifyListeners();
    }
    try {
      final saved = await _firestoreService.getLatestMultiModalPrediction(uid);
      if (_predictionOwnerUid != uid) return;
      if (saved == null) return;
      final currentTimestamp = _latestPrediction?.createdAt;
      final savedTimestamp = saved.createdAt;
      if (_latestPrediction == null ||
          (savedTimestamp != null &&
              (currentTimestamp == null ||
                  savedTimestamp.isAfter(currentTimestamp)))) {
        _latestPrediction = saved;
        notifyListeners();
      }
    } catch (error) {
      _errorMessage = 'Unable to load the latest screening result: $error';
      notifyListeners();
    }
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  String _buildCurrentPredictionSignature() {
    final assessmentSignature = _assessmentPayload == null
        ? 'assessment:null'
        : _assessmentPayload.toString();
    final assessmentResultSignature = _assessmentResult == null
        ? 'assessmentResult:null'
        : _assessmentResult.toString();
    final retinaSignature = _retinaResultMap == null
        ? 'retina:null'
        : _retinaResultMap.toString();
    final footSignature = _footResultMap == null
        ? 'foot:null'
        : _footResultMap.toString();
    return '$assessmentSignature|$assessmentResultSignature|$retinaSignature|$footSignature|${_retinaImageUrl ?? ''}|${_footImageUrl ?? ''}';
  }

  void setAssessmentResult(
      Map<String, dynamic> payload, Map<String, dynamic> result) {
    if (mapEquals(_assessmentPayload, payload) &&
        mapEquals(_assessmentResult, result)) {
      return;
    }
    _assessmentPayload = payload;
    _assessmentResult = Map<String, dynamic>.from(result);
    _assessmentScore =
        _validRiskPercentage(result['risk_percentage']);
    _latestPrediction = null;
    _pendingPrediction = null;
    _pendingUid = null;
    _currentPredictionSignature = null;
    _errorMessage = null;
    notifyListeners();
  }

  void invalidateCombinedPrediction() {
    _latestPrediction = null;
    _pendingPrediction = null;
    _pendingUid = null;
    _currentPredictionSignature = null;
    _errorMessage = null;
    notifyListeners();
  }

  Map<String, dynamic>? _retinaResultMap;
  Map<String, dynamic>? _footResultMap;

  Map<String, dynamic>? get retinaResultMap => _retinaResultMap;
  Map<String, dynamic>? get footResultMap => _footResultMap;

  void setRetinaResultMap(Map<String, dynamic> result) {
    if (mapEquals(_retinaResultMap, result)) return;
    _retinaResultMap = Map<String, dynamic>.from(result);
    _latestPrediction = null;
    _pendingPrediction = null;
    _pendingUid = null;
    _currentPredictionSignature = null;
    notifyListeners();
  }

  void setFootResultMap(Map<String, dynamic> result) {
    if (mapEquals(_footResultMap, result)) return;
    _footResultMap = Map<String, dynamic>.from(result);
    _latestPrediction = null;
    _pendingPrediction = null;
    _pendingUid = null;
    _currentPredictionSignature = null;
    notifyListeners();
  }

  void setRetinaScan({File? imageFile, required String imageUrl}) {
    if (_retinaImageFile?.path == imageFile?.path &&
        _retinaImageUrl == imageUrl) {
      return;
    }
    _retinaImageFile = imageFile;
    _retinaImageUrl = imageUrl;
    _retinaResultMap = null;
    invalidateCombinedPrediction();
  }

  void setFootScan({File? imageFile, required String imageUrl}) {
    if (_footImageFile?.path == imageFile?.path && _footImageUrl == imageUrl) {
      return;
    }
    _footImageFile = imageFile;
    _footImageUrl = imageUrl;
    _footResultMap = null;
    invalidateCombinedPrediction();
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
      invalidateCombinedPrediction();
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
      invalidateCombinedPrediction();
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
    if (_isAnalyzing) return false;
    final currentSignature = _buildCurrentPredictionSignature();
    if (_latestPrediction != null && _currentPredictionSignature == currentSignature) {
      return true;
    }
    if (!isReadyForPrediction) {
      _errorMessage =
          'Complete all three assessments before generating your final diabetes prediction.';
      notifyListeners();
      return false;
    }
    if (uid.isEmpty) {
      _errorMessage = 'Sign in before saving a combined screening result.';
      notifyListeners();
      return false;
    }

    if (_pendingPrediction != null) {
      if (_pendingUid != uid) {
        _errorMessage = 'A screening result belongs to a different user.';
        notifyListeners();
        return false;
      }
      _isAnalyzing = true;
      _errorMessage = null;
      notifyListeners();
      try {
        await _firestoreService.saveMultiModalRecord(
          uid: uid,
          prediction: _pendingPrediction!,
          assessmentPayload: _assessmentPayload!,
        );
        _latestPrediction = _pendingPrediction;
        _predictionOwnerUid = uid;
        _pendingPrediction = null;
        _pendingUid = null;
        _isAnalyzing = false;
        notifyListeners();
        return true;
      } catch (error) {
        _errorMessage = FirestoreService.userFacingError(
          error,
          operation: 'save the screening result',
        );
        _isAnalyzing = false;
        notifyListeners();
        return false;
      }
    }

    _isAnalyzing = true;
    _errorMessage = null;
    notifyListeners();

    debugPrint("--------------------------------------------------");
    debugPrint(
        "STEP 2: [MultiModalProvider] runCombinedMultiModalPrediction() called");

    try {
      final assessmentResult = _assessmentResult!;
      final assessmentScore =
          _validRiskPercentage(assessmentResult['risk_percentage']) ?? 0.0;

      final retinaText = (_retinaResultMap == null)
          ? ''
          : (_retinaResultMap!['prediction'] ?? '').toString();
      final retinaLower = retinaText.toLowerCase();
      final bool isRetinaAbnormal = retinaText.isNotEmpty &&
          !(retinaLower.contains('healthy fundus') ||
              retinaLower.contains('no retinopathy') ||
              (retinaLower.contains('healthy') && retinaLower.contains('normal')));

      final footMap = _footResultMap ?? const {};
      final footStatus = (footMap['status'] ?? footMap['prediction'] ?? '')
          .toString();
      final footUpper = footStatus.trim().toUpperCase();
      final bool isFootAbnormal = footStatus.isNotEmpty &&
          (footUpper.contains('MILD') ||
              footUpper.contains('SEVERE') ||
              footUpper.contains('ULCER') ||
              footUpper.contains('LESION'));

      final fusion = calculateFrontendFusion(
        assessmentScore: assessmentScore,
        retinaAbnormal: isRetinaAbnormal,
        footAbnormal: isFootAbnormal,
      );

      final riskLevelValue = fusion['riskLevel'] as String;
      final riskLevelEnum = switch (riskLevelValue) {
        'healthy' => RiskLevel.healthy,
        'prediabetic' => RiskLevel.prediabetic,
        'borderline' => RiskLevel.borderline,
        'highRisk' => RiskLevel.highRisk,
        _ => RiskLevel.inconclusive,
      };

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
      final nextScreening = DateTime(
        now.year + (riskLevelEnum == RiskLevel.healthy ? 1 : 0),
        now.month + 3,
        1,
      );
      final nextScreeningDate =
          '${nextScreening.year}-${nextScreening.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final overallScore = _validRiskPercentage(fusion['riskPercentage']) ?? 5.0;
      final retinaLabel = retinaText.isEmpty ? 'Not available' : retinaText;
      final footLabel = footStatus.isEmpty ? 'Not available' : footStatus;
      final recommendations = generateDynamicCarePlan(
        assessmentScore: assessmentScore,
        isRetinaAbnormal: isRetinaAbnormal,
        isFootAbnormal: isFootAbnormal,
      );

      final result = PredictionResult(
        id: now.microsecondsSinceEpoch.toString(),
        type: PredictionType.multiModalCombined,
        title: 'Multi-Modal Screening Result',
        date: dateStr,
        time: timeStr,
        createdAt: now,
        riskLevel: riskLevelEnum,
        predictionLabel: fusion['predictionLabel'] as String,
        riskPercentage: overallScore,
        confidencePercentage: null,
        assessmentScore: assessmentScore,
        assessmentClassProbabilities: const {},
        assessmentExplanation: 'Frontend rule-based assessment score.',
        assessmentProbabilityCalibration:
            'Rule-based demo score; not clinically validated.',
        retinaRiskPercentage: null,
        retinaConfidencePercentage: null,
        footRiskPercentage: null,
        footConfidencePercentage: null,
        retinaResult: retinaLabel,
        footResult: footLabel,
        carePlanStatus: 'Screening follow-up',
        retinaImageUrl: _retinaImageUrl,
        footImageUrl: _footImageUrl,
        nextScreeningDate: nextScreeningDate,
        recommendations: recommendations,
        source: 'frontend-rule-engine',
      );

      _pendingPrediction = result;
      _pendingUid = uid;
      await _firestoreService.saveMultiModalRecord(
        uid: uid,
        prediction: result,
        assessmentPayload: _assessmentPayload!,
      );

      _latestPrediction = result;
      _pendingPrediction = null;
      _pendingUid = null;
      _predictionOwnerUid = uid;
      _currentPredictionSignature = currentSignature;
      _isAnalyzing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = FirestoreService.userFacingError(
        e,
        operation: 'generate and save the combined screening result',
      );
      _isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  void resetWorkflow() {
    _assessmentPayload = null;
    _assessmentResult = null;
    _assessmentScore = null;
    _retinaImageFile = null;
    _retinaImageUrl = null;
    _retinaResultMap = null;
    _footImageFile = null;
    _footImageUrl = null;
    _footResultMap = null;
    _latestPrediction = null;
    _pendingPrediction = null;
    _pendingUid = null;
    _predictionOwnerUid = null;
    _currentPredictionSignature = null;
    _errorMessage = null;
    _isAnalyzing = false;
    notifyListeners();
  }
}
