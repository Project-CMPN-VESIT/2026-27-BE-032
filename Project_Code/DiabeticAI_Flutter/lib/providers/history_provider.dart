import 'dart:async';
import 'package:flutter/material.dart';
import '../models/prediction_result.dart';
import '../services/firestore_service.dart';

class HistoryProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription<List<PredictionResult>>? _subscription;
  List<PredictionResult> _history = [];
  bool _isLoading = false;

  List<PredictionResult> get history => _history;
  bool get isLoading => _isLoading;

  void fetchHistoryForUser(String uid) {
    if (uid.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _firestoreService.getPredictionHistory(uid).listen(
      (data) {
        _history = data;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  void addResult(PredictionResult result) {
    _history.insert(0, result);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
