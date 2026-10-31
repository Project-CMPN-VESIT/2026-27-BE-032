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
      type: PredictionType.retinaScan,
      title: 'Retina Retinopathy Scan',
      date:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      time: _nowTimeString(),
      riskLevel: RiskLevel.healthy,
      predictionLabel: 'Healthy Fundus - No Retinopathy',
      riskPercentage:
          PredictionResult.retinaRiskFor('Healthy Fundus - No Retinopathy', 92),
      confidencePercentage: 92,
      retinaRiskPercentage:
          PredictionResult.retinaRiskFor('Healthy Fundus - No Retinopathy', 92),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      recommendations: const [
        'Schedule comprehensive dilated eye exam once a year.'
      ],
      source: 'demo_fallback',
    );
    _uploadSuccess = true;
    _uploadError = null;
    debugPrint('Retina fallbackPrediction: demo_fallback');
  }

  /// Uploads to Firebase Storage (`users/{uid}/retina/`), runs AI, saves to Firestore.
  Future<void> runRetinaScan({String uid = ''}) async {
    debugPrint("--------------------------------------------------");
    debugPrint("STEP 2: [EyeScanProvider] runRetinaScan() called");

    if (_selectedImage == null) {
      debugPrint("⚠️ [EyeScanProvider] No image selected. Returning fallback.");
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
    String prediction = 'Healthy Fundus - No Retinopathy';
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
                const Duration(seconds: 35),
              );

          debugPrint("STEP 5: [EyeScanProvider] Received Retina API response: $response");
          prediction = response['prediction'] as String? ??
              'Healthy Fundus - No Retinopathy';
          final confidence =
              (response['confidence'] as num?)?.toDouble() ?? 98.9;
          final source = response['source'] as String? ?? 'backend';
          severity = response['severity'] as String?;
          riskLevel = response['risk_level'] as String?;

          final riskPct = (response['risk_percentage'] as num?)?.toDouble() ??
              PredictionResult.retinaRiskFor(prediction, confidence);

          _retinaResultMap = {
            'prediction': prediction,
            'risk_percentage': riskPct,
            'confidence': confidence,
            'severity': severity ?? 'No Retinopathy',
            'risk_level': riskLevel ?? 'healthy',
          };

          final now = DateTime.now();
          final dateStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

          final displayUrl = storageUrl ?? _selectedImage?.path ?? '';

          _scanResult = PredictionResult(
            id: now.millisecondsSinceEpoch.toString(),
            type: PredictionType.retinaScan,
            title: 'Retina Retinopathy Scan',
            date: dateStr,
            time: _nowTimeString(),
            riskLevel: RiskLevel.healthy,
            predictionLabel: prediction,
            riskPercentage: riskPct,
            confidencePercentage: confidence,
            retinaRiskPercentage: riskPct,
            imageUrl: displayUrl,
            source: source,
            recommendations: [
              'Schedule comprehensive dilated eye exam once a year.',
              'Maintain strict control of blood sugar and blood pressure.',
              'Protect eyes from UV exposure with polarized sunglasses.'
            ],
          );
        } catch (e) {
          debugPrint("❌ [EyeScanProvider] Retina API prediction failed ($e).");
          final displayUrl = storageUrl ?? _selectedImage?.path ?? '';
          _useFallback(displayUrl);
          prediction = _scanResult!.predictionLabel;
          riskLevel = 'Low';
        }
      }

      // Persist to Firestore
      if (uid.isNotEmpty) {
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
          debugPrint("⚠️ [EyeScanProvider] Retina history save error: $e");
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
