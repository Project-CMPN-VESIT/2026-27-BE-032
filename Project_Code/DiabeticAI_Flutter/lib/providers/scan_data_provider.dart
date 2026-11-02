import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';

/// Central provider for cross-module scan state and the signed-in user's latest
/// saved screening data.
class ScanDataProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  String? _ownerUid;
  String? _loadError;
  bool _isLoading = false;
  int _loadGeneration = 0;
  int? _totalScans;
  double? _bmi;

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
  double? _assessmentScore;

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
  double? get assessmentScore => _assessmentScore;
  int? get totalScans => _totalScans;
  double? get bmi => _bmi;
  String? get loadError => _loadError;
  bool get isLoading => _isLoading;

  bool get isRetinaComplete => (_retinaUrl ?? '').isNotEmpty;
  bool get isFootComplete => (_footUrl ?? '').isNotEmpty;
  bool get isAssessmentComplete => _assessmentDone;

  bool get isReadyForFinalPrediction =>
      isRetinaComplete && isFootComplete && isAssessmentComplete;

  /// Loads only records scoped to the authenticated user's UID.
  Future<void> loadForUser(String uid) async {
    if (uid.isEmpty) return;
    if (_ownerUid != uid) {
      _ownerUid = uid;
      _clearValues();
    }
    final generation = ++_loadGeneration;
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      final records = await Future.wait<Object?>([
        _firestoreService.getAssessmentRecord(uid),
        _firestoreService.getFootRecord(uid),
        _firestoreService.getRetinaRecord(uid),
        _firestoreService.countPredictionHistory(uid),
      ]);
      if (_ownerUid != uid || generation != _loadGeneration) return;

      final assessment = records[0] as Map<String, dynamic>?;
      final foot = records[1] as Map<String, dynamic>?;
      final retina = records[2] as Map<String, dynamic>?;
      final payload = _mapValue(assessment?['payload']);
      final result = _mapValue(assessment?['result']);

      _assessmentPayload = payload;
      _assessmentResult = result;
      _assessmentDone = result != null;
      _assessmentScore = _validPercentage(result?['risk_percentage']);
      _bmi = _validPositiveNumber(payload?['BMI']);
      _footUrl = _stringValue(foot?['imageUrl']);
      _footResult = _stringValue(foot?['prediction']);
      _retinaUrl = _stringValue(retina?['imageUrl']);
      _retinaResult = _stringValue(retina?['prediction']);
      _totalScans = records[3] as int;
      _isLoading = false;
      _loadError = null;
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('[ScanDataProvider] Failed to load saved scan data: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (_ownerUid == uid && generation == _loadGeneration) {
        _isLoading = false;
        _loadError = 'Saved screening data could not be loaded.';
        notifyListeners();
      }
    }
  }

  String? _stringValue(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  Map<String, dynamic>? _mapValue(Object? value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  double? _validPercentage(Object? value) {
    if (value is! num || !value.isFinite || value < 0 || value > 100) {
      return null;
    }
    return value.toDouble();
  }

  double? _validPositiveNumber(Object? value) {
    if (value is! num || !value.isFinite || value <= 0) return null;
    return value.toDouble();
  }

  /// Called by EyeScanProvider after a successful scan and Firestore save.
  void setRetinaData(String url, String result) {
    _retinaUrl = url;
    _retinaResult = result;
    _retinaUploadedAt = DateTime.now();
    notifyListeners();
  }

  /// Called by FootScanProvider after a successful scan and Firestore save.
  void setFootData(String url, String result) {
    _footUrl = url;
    _footResult = result;
    _footUploadedAt = DateTime.now();
    notifyListeners();
  }

  /// Called after the assessment API response has been validated and saved.
  void setAssessmentData(
      Map<String, dynamic> payload, Map<String, dynamic> result) {
    _assessmentPayload = Map<String, dynamic>.from(payload);
    _assessmentResult = Map<String, dynamic>.from(result);
    _assessmentScore = _validPercentage(result['risk_percentage']);
    _bmi = _validPositiveNumber(payload['BMI']);
    _assessmentDone = true;
    notifyListeners();
  }

  void _clearValues() {
    _loadError = null;
    _isLoading = false;
    _totalScans = null;
    _bmi = null;
    _retinaUrl = null;
    _retinaResult = null;
    _retinaUploadedAt = null;
    _footUrl = null;
    _footResult = null;
    _footUploadedAt = null;
    _assessmentDone = false;
    _assessmentPayload = null;
    _assessmentResult = null;
    _assessmentScore = null;
  }

  void clearAll() {
    _loadGeneration++;
    _clearValues();
    notifyListeners();
  }
}
