import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/prediction_result.dart';
import '../services/api_service.dart';
import '../services/firebase_storage_service.dart';
import '../services/firestore_service.dart';
import '../services/image_validation_service.dart';

class EyeScanProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FirebaseStorageService _storageService = FirebaseStorageService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  String? _uploadedImageUrl;
  PredictionResult? _scanResult;
  Map<String, dynamic>? _retinaResultMap;
  bool _isAnalyzing = false;
  bool _uploadSuccess = false;
  String? _validationError;
  String? _uploadError;

  File? get selectedImage => _selectedImage;
  String? get uploadedImageUrl => _uploadedImageUrl;
  PredictionResult? get scanResult => _scanResult;
  Map<String, dynamic>? get retinaResultMap => _retinaResultMap;
  bool get isAnalyzing => _isAnalyzing;
  bool get uploadSuccess => _uploadSuccess;
  String? get validationError => _validationError;
  String? get uploadError => _uploadError;

  void reset() {
    _selectedImage = null;
    _uploadedImageUrl = null;
    _scanResult = null;
    _retinaResultMap = null;
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
        ScanImageType.retina,
      );

      if (!validation.isValid) {
        _validationError = validation.errorMessage;
        _selectedImage = null;
        _scanResult = null;
        _retinaResultMap = null;
        _uploadSuccess = false;
        notifyListeners();
        return;
      }

      _validationError = null;
      _uploadError = null;
      _selectedImage = selectedFile;
      _scanResult = null;
      _retinaResultMap = null;
      _uploadedImageUrl = null;
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



  /// Uploads to Firebase Storage (`users/{uid}/retina/`), runs AI, saves to Firestore.
  Future<void> runRetinaScan({String uid = ''}) async {
    debugPrint("--------------------------------------------------");
    debugPrint("STEP 2: [EyeScanProvider] runRetinaScan() called");

    if (_scanResult != null && _uploadSuccess) return;
    if (_isAnalyzing) return;
    if (_selectedImage == null) {
      debugPrint("⚠️ [EyeScanProvider] No image selected.");
      _validationError = "Please select a retinal fundus image before starting the scan.";
      notifyListeners();
      return;
    }
    _isAnalyzing = true;
    _uploadSuccess = false;
    _uploadError = null;
    _validationError = null;
    notifyListeners();

    String? storageUrl;
    String? severity;
    String? riskLevel;
    try {
      try {
        debugPrint("STEP 3: [EyeScanProvider] Starting Firebase Storage upload for ${_selectedImage!.path}");
        final uploaded = await _storageService.uploadImage(
          _selectedImage!,
          folder: 'retina',
          uid: uid,
        );
        if (uploaded.startsWith('http')) {
          storageUrl = uploaded;
          _uploadedImageUrl = storageUrl;
          debugPrint("STEP 3a: [EyeScanProvider] Firebase Storage upload completed -> $storageUrl");
        } else {
          debugPrint("⚠️ [EyeScanProvider] Firebase Storage upload did not return HTTP URL. Will use Multipart/Form-Data.");
          storageUrl = null;
        }
      } on FirebaseStorageUploadException catch (e) {
        debugPrint("⚠️ [EyeScanProvider] Firebase Storage upload failed ($e). Will use Multipart/Form-Data upload.");
        storageUrl = null;
      } catch (e) {
        debugPrint("⚠️ [EyeScanProvider] Unexpected Storage upload error ($e). Will use Multipart/Form-Data upload.");
        storageUrl = null;
      }

      // Run AI prediction
      if (_scanResult == null) {
        try {
          debugPrint("STEP 4: [EyeScanProvider] Calling ApiService.predictRetina()...");
          final response = await _apiService
              .predictRetina(
                imageUrl: (storageUrl != null && storageUrl.startsWith('http')) ? storageUrl : null,
                imageFile: (storageUrl == null || !storageUrl.startsWith('http')) ? _selectedImage : null,
              )
              .timeout(
                const Duration(seconds: 60),
              );

          debugPrint("STEP 5: [EyeScanProvider] Received Retina API response: $response");
          if (response['success'] != true ||
              response['prediction'] is! String ||
              (response['prediction'] as String).trim().isEmpty) {
            throw const FormatException(
                'Retina prediction response is missing its result.');
          }
          final prediction = response['prediction'] as String;
          final confidenceValue = response['confidence'];
          final confidence = confidenceValue is num &&
                  confidenceValue.isFinite &&
                  confidenceValue >= 0 &&
                  confidenceValue <= 100
              ? confidenceValue.toDouble()
              : null;
          final source = response['source'] as String? ?? 'backend';
          severity = response['severity'] as String?;
          riskLevel = response['risk_level'] as String?;
          if (riskLevel == null || riskLevel.isEmpty) {
            throw const FormatException(
                'Retina prediction response is missing its classification.');
          }

          final riskValue = response['risk_percentage'];
          final riskPct = riskValue is num &&
                  riskValue.isFinite &&
                  riskValue >= 0 &&
                  riskValue <= 100
              ? riskValue.toDouble()
              : null;

          _retinaResultMap = {
            'prediction': prediction,
            'risk_percentage': riskPct,
            'confidence': confidence,
            if (severity != null) 'severity': severity,
            'risk_level': riskLevel,
          };

          final now = DateTime.now();
          final dateStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

          final displayUrl = storageUrl ?? _selectedImage?.path ?? '';

          RiskLevel calculatedRisk = RiskLevel.healthy;
          final predLower = prediction.toLowerCase();
          if (predLower.contains('proliferative') || predLower.contains('severe')) {
            calculatedRisk = RiskLevel.highRisk;
          } else if (predLower.contains('moderate') || (predLower.contains('retinopathy') && !predLower.contains('no retinopathy'))) {
            calculatedRisk = RiskLevel.diabetic;
          } else if (predLower.contains('mild')) {
            calculatedRisk = RiskLevel.prediabetic;
          }

          _scanResult = PredictionResult(
            id: now.microsecondsSinceEpoch.toString(),
            type: PredictionType.retinaScan,
            title: 'Retina Retinopathy Scan',
            date: dateStr,
            time: _nowTimeString(),
            createdAt: now,
            riskLevel: calculatedRisk,
            predictionLabel: prediction,
            riskPercentage: riskPct,
            confidencePercentage: confidence,
            retinaRiskPercentage: riskPct,
            imageUrl: displayUrl,
            source: source,
            recommendations: calculatedRisk == RiskLevel.healthy
                ? const [
                    'Schedule comprehensive dilated eye exam once a year.',
                    'Maintain strict control of blood sugar and blood pressure.',
                    'Protect eyes from UV exposure with polarized sunglasses.'
                  ]
                : const [
                    'Immediate ophthalmologist consultation & dilated eye exam.',
                    'Strict daily blood sugar monitoring (fasting & post-prandial).',
                    'Request diagnostic HbA1c laboratory blood test.',
                    'Implement low-glycemic, heart-healthy dietary changes.'
                  ],
          );
        } catch (e) {
          debugPrint("❌ [EyeScanProvider] Retina API prediction failed ($e).");
          _uploadError = "Connection Error: Unable to reach prediction server ($e). Please verify backend/tunnel status.";
          _uploadSuccess = false;
          _isAnalyzing = false;
          notifyListeners();
          return;
        }
      }

      // Persist to Firestore
      if (uid.isEmpty) {
        _uploadError = 'Sign in before saving a retina result.';
        return;
      }
      try {
        final displayUrl = storageUrl ?? _selectedImage?.path ?? '';
        debugPrint("STEP 6: [EyeScanProvider] Saving Retina record to Firestore...");
        await _firestoreService
            .saveRetinaRecord(
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
        debugPrint("STEP 6a: [EyeScanProvider] Firestore save complete.");
      } catch (e) {
        _uploadError = FirestoreService.userFacingError(
          e,
          operation: 'save the retina screening result',
        );
        _uploadSuccess = false;
        return;
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
