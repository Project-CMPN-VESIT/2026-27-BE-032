import 'dart:async';
import 'package:flutter/material.dart';
import '../models/prediction_result.dart';
import '../services/firestore_service.dart';

class HistoryProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<List<PredictionResult>>? _subscription;
  List<PredictionResult> _history = [];
  bool _isLoading = false;
  bool _isClearing = false;
  String? _currentUid;
  String? _errorMessage;

  List<PredictionResult> get history => _history;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void fetchHistoryForUser(String uid) {
    if (uid.isEmpty || (_currentUid == uid && _subscription != null)) return;
    _currentUid = uid;
    _history = [];
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    try {
      _subscription = _firestoreService.getPredictionHistory(uid).listen(
        (data) {
          if (_currentUid != uid || _isClearing) return;
          _history = _newestFirst(data).take(10).toList();
          _isLoading = false;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (Object error) {
          if (_currentUid != uid) return;
          _isLoading = false;
          _errorMessage = FirestoreService.userFacingError(
            error,
            operation: 'load prediction history',
          );
          notifyListeners();
        },
      );
    } catch (error) {
      if (_currentUid != uid) return;
      _isLoading = false;
      _errorMessage = FirestoreService.userFacingError(
        error,
        operation: 'load prediction history',
      );
      notifyListeners();
    }
  }

  void addResult(PredictionResult result) {
    _history = _newestFirst([result, ..._history]).take(10).toList();
    notifyListeners();
  }

  Future<void> clearHistory(String uid) async {
    if (uid.isEmpty || uid != _currentUid) {
      throw StateError('Cannot clear history for a different signed-in user.');
    }

    final previousHistory = _history;
    _isClearing = true;
    _history = [];
    _errorMessage = null;
    notifyListeners();

    try {
      await _firestoreService.deletePredictionHistory(uid);
      _isClearing = false;
    } catch (error) {
      _isClearing = false;
      if (_currentUid == uid) {
        _history = previousHistory;
        _errorMessage = FirestoreService.userFacingError(
          error,
          operation: 'clear prediction history',
        );
        notifyListeners();
      }
      rethrow;
    }
  }

  List<PredictionResult> _newestFirst(Iterable<PredictionResult> records) {
    final sorted = records.toList();
    sorted.sort((a, b) {
      final aTimestamp =
          a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTimestamp =
          b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timestampOrder = bTimestamp.compareTo(aTimestamp);
      return timestampOrder != 0 ? timestampOrder : b.id.compareTo(a.id);
    });
    return sorted;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
