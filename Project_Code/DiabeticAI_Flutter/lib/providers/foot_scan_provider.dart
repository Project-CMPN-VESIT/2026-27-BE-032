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
  int _scanGeneration = 0;

  File? get selectedImage => _selectedImage;
  String? get uploadedImageUrl => _uploadedImageUrl;
  PredictionResult? get scanResult => _scanResult;
  Map<String, dynamic>? get footResultMap => _footResultMap;
  bool get isAnalyzing => _isAnalyzing;
  bool get uploadSuccess => _uploadSuccess;
  String? get validationError => _validationError;
  String? get uploadError => _uploadError;

  void reset() {
    _scanGeneration++;
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
    if (_isAnalyzing) return;
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
        _footResultMap = null;
        _uploadSuccess = false;
        notifyListeners();
        return;
      }

      _validationError = null;
      _uploadError = null;
      _scanGeneration++;
      _selectedImage = selectedFile;
      _scanResult = null;
      _footResultMap = null;
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

  /// Uploads to Firebase Storage (`users/{uid}/foot/`), runs AI, saves to Firestore.
  Future<void> runFootScan({String uid = ''}) async {
    debugPrint("--------------------------------------------------");
    debugPrint("STEP 2: [FootScanProvider] runFootScan() called");

    if (_scanResult != null && _uploadSuccess) return;
    if (_isAnalyzing) return;
    if (_selectedImage == null) {
      debugPrint(
          "⚠️ [FootScanProvider] No image selected; analysis was not run.");
      _scanResult = null;
      _footResultMap = null;
      _uploadSuccess = false;
      _uploadError = 'Select a foot image before running analysis.';
      notifyListeners();
      return;
    }
    _isAnalyzing = true;
    final scanGeneration = _scanGeneration;
    final scanImage = _selectedImage!;
    _uploadSuccess = false;
    _uploadError = null;
    _validationError = null;
    notifyListeners();

    String? storageUrl;
    String? riskLevel;
    String? finding;
    String? description;
    String? reason;
    String? source;
    try {
      try {
        debugPrint(
            "STEP 3: [FootScanProvider] Starting Firebase Storage upload for ${_selectedImage!.path}");
        final uploaded = await _storageService.uploadImage(
          scanImage,
          folder: 'foot',
          uid: uid,
        );
        if (uploaded.startsWith('http')) {
          storageUrl = uploaded;
          _uploadedImageUrl = storageUrl;
          debugPrint(
              "STEP 3a: [FootScanProvider] Firebase Storage upload completed -> $storageUrl");
        } else {
          debugPrint(
              "⚠️ [FootScanProvider] Firebase Storage upload did not return HTTP URL. Will use Multipart/Form-Data.");
          storageUrl = null;
        }
      } on FirebaseStorageUploadException catch (e) {
        debugPrint(
            "⚠️ [FootScanProvider] Firebase Storage upload failed ($e). Will use Multipart/Form-Data upload.");
        storageUrl = null;
      } catch (e) {
        debugPrint(
            "⚠️ [FootScanProvider] Unexpected Storage upload error ($e). Will use Multipart/Form-Data upload.");
        storageUrl = null;
      }

      if (scanGeneration != _scanGeneration) return;

      if (_scanResult == null) {
        try {
          debugPrint(
              "STEP 4: [FootScanProvider] Calling ApiService.predictFootUlcer()...");
          final response = await _apiService
              .predictFootUlcer(
                imageFile: scanImage,
              )
              .timeout(
                const Duration(seconds: 60),
              );

          debugPrint(
              "STEP 5: [FootScanProvider] Received Foot API response: $response");
          if (response['success'] != true ||
              response['status'] is! String ||
              response['finding'] is! String ||
              response['description'] is! String ||
              response['reason'] is! String ||
              response['model'] is! String ||
              response['screening_mode'] is! String ||
              response['image_metrics'] is! Map ||
              (response['demo_mode'] != null &&
                  response['demo_mode'] is! String) ||
              response['regions'] is! List) {
            throw const FormatException(
                'Foot prediction response is missing required fields.');
          }

          final status = response['status'] as String;
          if (!const {
            'NORMAL',
            'MILD FINDING',
            'SEVERE FINDING',
            'ULCER SUSPECTED',
            'INCONCLUSIVE',
          }.contains(status)) {
            throw const FormatException('Unknown foot classification status.');
          }
          finding = response['finding'] as String;
          description = response['description'] as String;
          source = response['model'] as String;
          riskLevel = switch (status) {
            'NORMAL' => 'healthy',
            'SEVERE FINDING' || 'ULCER SUSPECTED' => 'borderline',
            _ => 'inconclusive',
          };
          reason = response['reason'] as String;
          if (scanGeneration != _scanGeneration) return;

          _footResultMap = {
            'status': status,
            'prediction': status,
            'finding': finding,
            'description': description,
            'risk_percentage': null,
            'risk_level': riskLevel,
            'reason': reason,
            'model': source,
            'demo_mode': response['demo_mode'] as String?,
            'screening_mode': response['screening_mode'] as String,
            'confidence': response['confidence'],
            'image_metrics':
                Map<String, dynamic>.from(response['image_metrics'] as Map),
            'regions': response['regions'] is List
                ? (response['regions'] as List)
                    .whereType<Map<String, dynamic>>()
                    .toList()
                : const <Map<String, dynamic>>[],
          };

          final now = DateTime.now();
          final dateStr =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final displayUrl = storageUrl ?? _selectedImage?.path ?? '';
          final resultRiskLevel = switch (status) {
            'NORMAL' => RiskLevel.healthy,
            'MILD FINDING' => RiskLevel.inconclusive,
            'SEVERE FINDING' || 'ULCER SUSPECTED' => RiskLevel.borderline,
            _ => RiskLevel.inconclusive,
          };

          _scanResult = PredictionResult(
            id: now.microsecondsSinceEpoch.toString(),
            type: PredictionType.footUlcerScan,
            title: 'Foot Skin Screening',
            date: dateStr,
            time: _nowTimeString(),
            createdAt: now,
            riskLevel: resultRiskLevel,
            predictionLabel: status,
            riskPercentage: null,
            confidencePercentage: null,
            footRiskPercentage: null,
            imageUrl: displayUrl,
            footImageUrl: displayUrl,
            source: source,
            footResult: finding,
            footFinding: finding,
            footReason: reason,
          );
        } catch (e) {
          debugPrint("❌ [FootScanProvider] Foot API prediction failed ($e).");
          _uploadError = ApiService.footPredictionError(e);
          _uploadSuccess = false;
          _isAnalyzing = false;
          notifyListeners();
          return;
        }
      }

      if (scanGeneration != _scanGeneration) return;

      // Persist to Firestore
      if (uid.isEmpty) {
        _uploadError = 'Sign in before saving a foot screening result.';
        return;
      }
      try {
        final displayUrl = storageUrl ?? _selectedImage?.path ?? '';
        debugPrint(
            "STEP 6: [FootScanProvider] Saving Foot record to Firestore...");
        await _firestoreService
            .saveFootRecord(
              uid,
              displayUrl,
              _scanResult!.predictionLabel,
              riskPercentage: _scanResult!.riskPercentage,
              riskLevel: riskLevel,
              finding: _scanResult!.footFinding,
              description: _scanResult!.footResult,
              reason: _scanResult!.footReason,
            )
            .timeout(const Duration(seconds: 10));
        await _firestoreService
            .savePrediction(uid, _scanResult!)
            .timeout(const Duration(seconds: 10));
        debugPrint("STEP 6a: [FootScanProvider] Firestore save complete.");
      } catch (e) {
        _uploadError = FirestoreService.userFacingError(
          e,
          operation: 'save the foot screening result',
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
