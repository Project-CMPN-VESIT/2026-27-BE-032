import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../services/api_service.dart';

/// Central provider for cross-module scan state.
/// Loads and persists retina & foot Firebase Storage URLs + AI results from Firestore.
/// Screens check [isReadyForFinalPrediction] to enable the combined prediction.
class ScanDataProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final ApiService _apiService = ApiService();

  // ── Retina ─────────────────────────────────────────────────────────────────
  String? _retinaUrl;
  String? _retinaResult;
  DateTime? _retinaUploadedAt;

  // ── Foot ───────────────────────────────────────────────────────────────────
  String? _footUrl;
  String? _footResult;
  DateTime? _footUploadedAt;

  // ── Assessment ─────────────────────────────────────────────────────────────
  bool _assessmentDone = false;
  Map<String, dynamic>? _assessmentPayload;
  Map<String, dynamic>? _assessmentResult;
  double _assessmentScore = 0.0;

  // ── Getters ────────────────────────────────────────────────────────────────
  String? get retinaUrl => _retinaUrl;
  String? get retinaResult => _retinaResult;
  DateTime? get retinaUploadedAt => _retinaUploadedAt;

  String? get footUrl => _footUrl;
  String? get footResult => _footResult;
  DateTime? get footUploadedAt => _footUploadedAt;

  bool get assessmentDone => _assessmentDone;
  Map<String, dynamic>? get assessmentPayload => _assessmentPayload;
  Map<String, dynamic>? get assessmentResult => _assessmentResult;
  double get assessmentScore => _assessmentScore;

  bool get isRetinaComplete => (_retinaUrl ?? '').isNotEmpty;
  bool get isFootComplete => (_footUrl ?? '').isNotEmpty;
  bool get isAssessmentComplete => _assessmentDone;

  /// All three modules complete → final prediction can be generated.
  bool get isReadyForFinalPrediction =>
      isRetinaComplete && isFootComplete && isAssessmentComplete;

  // ── Load from Firestore ─────────────────────────────────────────────────────
  Future<void> loadForUser(String uid) async {
    // Previous Firestore scans must not leak into a new login session.
    debugPrint(
        '[ScanDataProvider] automatic session restore disabled for $uid');
  }

  /// Called by EyeScanProvider after successful Firebase Storage upload + Firestore save.
  void setRetinaData(String url, String result) {
    _retinaUrl = url;
    _retinaResult = result;
    _retinaUploadedAt = DateTime.now();
    notifyListeners();
  }

  /// Called by FootScanProvider after successful Firebase Storage upload + Firestore save.
  void setFootData(String url, String result) {
    _footUrl = url;
    _footResult = result;
    _footUploadedAt = DateTime.now();
    notifyListeners();
  }

  /// Called by DiabetesAssessmentScreen after form validated.
  void setAssessmentData(Map<String, dynamic> payload, double score) {
    _assessmentPayload = payload;
    _assessmentScore = score;
    _assessmentDone = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(_saveAssessment(uid, payload));
    }

    notifyListeners();
  }

  Future<void> _saveAssessment(String uid, Map<String, dynamic> payload) async {
    final result = await _apiService.predictDiabetes(payload);
    await _firestoreService.saveAssessmentRecord(uid, payload, result);
  }

  void clearAll() {
    _retinaUrl = null;
    _retinaResult = null;
    _retinaUploadedAt = null;
    _footUrl = null;
    _footResult = null;
    _footUploadedAt = null;
    _assessmentDone = false;
    _assessmentPayload = null;
    _assessmentScore = 0.0;
    notifyListeners();
  }
}
