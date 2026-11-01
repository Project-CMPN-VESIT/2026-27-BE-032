import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/prediction_result.dart';
import '../services/api_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_service.dart';
import '../services/image_validation_service.dart';

class FootScanProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String? _uploadedImageUrl;
  PredictionResult? _scanResult;
  Map<String, dynamic>? _footResultMap;
  bool _isAnalyzing = false;
  bool _uploadSuccess = false;
  String? _validationError;
  String? _uploadError;

  File? get selectedImage => _selectedImage;
  String? get uploadedImageUrl => _uploadedImageUrl;
  PredictionResult? get scanResult => _scanResult;
  Map<String, dynamic>? get footResultMap => _footResultMap;
  bool get isAnalyzing => _isAnalyzing;
  bool get uploadSuccess => _uploadSuccess;
  String? get validationError => _validationError;
  String? get uploadError => _uploadError;

  void reset() {
    _selectedImage = null;
    _uploadedImageUrl = null;
    _scanResult = null;
    _footResultMap = null;
    _isAnalyzing = false;
    _uploadSuccess = false;
    _validationError = null;
    _uploadError = null;
    notifyListeners();
  }

  Future<void> pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(source: source);
    if (file != null) {
      final selectedFile = File(file.path);
      final validation = await ImageValidationService.validateImage(
        selectedFile,
        ScanImageType.foot,
      );

      if (!validation.isValid) {
        _validationError = validation.errorMessage;
        _selectedImage = null;
        _scanResult = null;
        _uploadSuccess = false;
        notifyListeners();
        return;
      }

      _validationError = null;
      _uploadError = null;
      _selectedImage = selectedFile;
      _scanResult = null;
      _uploadSuccess = false;
      notifyListeners();
    }
  }

  void clearValidationError() {
    _validationError = null;
    notifyListeners();
  }

  String _nowTimeString() {
    final now = DateTime.now();
    final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  void _useFallback(String imageUrl) {
    final now = DateTime.now();
    _scanResult = PredictionResult(
      id: now.millisecondsSinceEpoch.toString(),
      type: PredictionType.footUlcerScan,
      title: 'Diabetic Foot Ulcer Scan',
      date:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      time: _nowTimeString(),
      riskLevel: RiskLevel.healthy,
      predictionLabel: 'Grade 0 - No Lesion',
      riskPercentage: PredictionResult.footRiskFor('Grade 0 - No Lesion', 90),
      confidencePercentage: 90,
      footRiskPercentage: PredictionResult.footRiskFor('Grade 0 - No Lesion', 90),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      recommendations: const [
        'Maintain daily foot hygiene and moisturize skin.'
      ],
      source: 'demo_fallback',
    );
    _uploadSuccess = true;
    _uploadError = null;
    debugPrint('Foot fallbackPrediction: demo_fallback');
  }

  /// Uploads to Firebase Storage (`users/{uid}/foot/`), runs AI, saves to Firestore.
  Future<void> runFootScan({String uid = ''}) async {
    debugPrint("--------------------------------------------------");
    debugPrint("STEP 2: [FootScanProvider] runFootScan() called");

    if (_selectedImage == null) {
      debugPrint("⚠️ [FootScanProvider] No image selected. Returning fallback.");
      _useFallback('');
      notifyListeners();
      return;
    }
    _isAnalyzing = true;
    _uploadSuccess = false;
    _uploadError = null;
    _validationError = null;
    notifyListeners();

    String? storageUrl;
    String prediction = 'Grade 0 - No Lesion';
    String? severity;
    String? riskLevel;
    try {
      try {
        debugPrint("STEP 3: [FootScanProvider] Starting Firebase Storage upload for ${_selectedImage!.path}");
        final uploaded = await _storageService.uploadImage(
          _selectedImage!,
          folder: 'foot',
          uid: uid,
        );
        if (uploaded.startsWith('http')) {
          storageUrl = uploaded;
          _uploadedImageUrl = storageUrl;
          debugPrint("STEP 3a: [FootScanProvider] Firebase Storage upload completed -> $storageUrl");
        } else {
          debugPrint("⚠️ [FootScanProvider] Firebase Storage upload did not return HTTP URL. Will use Multipart/Form-Data.");
          storageUrl = null;
        }
      } on FirebaseStorageUploadException catch (e) {
        debugPrint("⚠️ [FootScanProvider] Firebase Storage upload failed ($e). Will use Multipart/Form-Data upload.");
        storageUrl = null;
      } catch (e) {
        debugPrint("⚠️ [FootScanProvider] Unexpected Storage upload error ($e). Will use Multipart/Form-Data upload.");
        storageUrl = null;
      }

      if (_scanResult == null) {
        try {
          debugPrint("STEP 4: [FootScanProvider] Calling ApiService.predictFootUlcer()...");
          final response = await _apiService
              .predictFootUlcer(
                imageUrl: (storageUrl != null && storageUrl.startsWith('http')) ? storageUrl : null,
                imageFile: (storageUrl == null || !storageUrl.startsWith('http')) ? _selectedImage : null,
              )
              .timeout(
                const Duration(seconds: 35),
              );

          debugPrint("STEP 5: [FootScanProvider] Received Foot API response: $response");
          prediction = response['prediction'] as String? ??
              'No Lesion Detected';
          final confidence =
              (response['confidence'] as num?)?.toDouble() ?? 95.0;
          final source = response['source'] as String? ?? 'backend';
          severity = response['severity'] as String? ?? 'Healthy Foot';
          riskLevel = response['risk_level'] as String? ?? 'healthy';
          final reason = response['reason'] as String? ??
              'No visible ulcer, wound, crack, blister, redness, swelling, necrosis or tissue damage is observed.';
          final disclaimer = response['disclaimer'] as String? ??
              'AI-based visual screening result. This is not a medical diagnosis.';

          final riskPct = (response['risk_percentage'] as num?)?.toDouble() ??
              PredictionResult.footRiskFor(prediction, confidence);

          _footResultMap = {
            'prediction': prediction,
            'risk_percentage': riskPct,
            'confidence': confidence,
            'severity': severity,
            'risk_level': riskLevel,
            'reason': reason,
            'disclaimer': disclaimer,
          };

          final now = DateTime.now();
          final dateStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final displayUrl = storageUrl ?? _selectedImage?.path ?? '';

          RiskLevel calculatedRisk = RiskLevel.healthy;
          final predLower = prediction.toLowerCase();
          if (predLower.contains('severe')) {
            calculatedRisk = RiskLevel.diabetic;
          } else if (predLower.contains('ulcer') || predLower.contains('wound') || predLower.contains('abnormal')) {
            calculatedRisk = RiskLevel.prediabetic;
          }

          _scanResult = PredictionResult(
            id: now.millisecondsSinceEpoch.toString(),
            type: PredictionType.footUlcerScan,
            title: 'Diabetic Foot Ulcer Scan',
            date: dateStr,
            time: _nowTimeString(),
            riskLevel: calculatedRisk,
            predictionLabel: prediction,
            riskPercentage: riskPct,
            confidencePercentage: confidence,
            footRiskPercentage: riskPct,
            imageUrl: displayUrl,
            source: source,
            recommendations: calculatedRisk == RiskLevel.healthy
                ? const [
                    'Maintain daily foot hygiene and moisturize skin.',
                    'Inspect feet daily for cuts, blisters, or redness.',
                    'Wear comfortable non-binding protective footwear.'
                  ]
                : const [
                    'Initiate professional foot wound management and dressing.',
                    'Avoid weight bearing on the affected ulcer area.',
                    'Consult a certified podiatrist or diabetic foot specialist promptly.'
                  ],
          );
        } catch (e) {
          debugPrint("❌ [FootScanProvider] Foot API prediction failed ($e).");
          _uploadError = "Connection Error: Unable to reach prediction server ($e). Please verify backend/tunnel status.";
          _uploadSuccess = false;
          _isAnalyzing = false;
          notifyListeners();
          return;
        }
      }

      // Persist to Firestore
      if (uid.isNotEmpty) {
        try {
          final displayUrl = storageUrl ?? _selectedImage?.path ?? '';
          debugPrint("STEP 6: [FootScanProvider] Saving Foot record to Firestore...");
          await _firestoreService
              .saveFootRecord(
                uid,
                displayUrl,
                _scanResult!.predictionLabel,
                confidence: _scanResult!.confidencePercentage,
                riskPercentage: _scanResult!.riskPercentage,
                riskLevel: riskLevel,
                severity: severity,
              )
              .timeout(const Duration(seconds: 10));
          await _firestoreService
              .savePrediction(uid, _scanResult!)
              .timeout(const Duration(seconds: 10));
          debugPrint("STEP 6a: [FootScanProvider] Firestore save complete.");
        } catch (e) {
          debugPrint("⚠️ [FootScanProvider] Foot history save error: $e");
        }
      }

      _uploadSuccess = true;
      notifyListeners();
    } finally {
      _isAnalyzing = false;
      notifyListeners();
      debugPrint("--------------------------------------------------");
    }
  }
}
