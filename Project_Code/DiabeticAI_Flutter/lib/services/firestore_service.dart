import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/prediction_result.dart';
import '../models/user_model.dart';

/// Handles Cloud Firestore database operations with debug logging and robust error handling.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── User Document Methods ────────────────────────────────────────────────

  /// Creates or updates a user document at `users/{uid}`.
  /// Uses [SetOptions.merge] to ensure idempotency.
  Future<void> createUser({
    required String uid,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    debugPrint('[FirestoreService] createUser() START → uid=$uid');
    final data = <String, dynamic>{
      'uid': uid,
      'fullName': fullName.trim(),
      'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
      debugPrint('[FirestoreService] createUser() SUCCESS ✓ for uid=$uid');
    } on FirebaseException catch (e, st) {
      debugPrint(
          '[FirestoreService] createUser() ERROR ✗ code=${e.code}, message=${e.message}');
      debugPrint(st.toString());
      rethrow;
    } catch (e, st) {
      debugPrint(
          '[FirestoreService] createUser() UNEXPECTED ERROR ✗ type=${e.runtimeType}, error=$e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Fetches user document from `users/{uid}`.
  /// Returns `null` if the document does not exist.
  Future<UserModel?> getUser(String uid) async {
    debugPrint('[FirestoreService] getUser() START → uid=$uid');
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        debugPrint(
            '[FirestoreService] getUser() → Document NOT FOUND for uid=$uid');
        return null;
      }
      debugPrint('[FirestoreService] getUser() SUCCESS ✓ for uid=$uid');
      return UserModel.fromMap(doc.data()!, uid);
    } on FirebaseException catch (e, st) {
      debugPrint(
          '[FirestoreService] getUser() ERROR ✗ code=${e.code}, message=${e.message}');
      debugPrint(st.toString());
      rethrow;
    } catch (e, st) {
      debugPrint(
          '[FirestoreService] getUser() UNEXPECTED ERROR ✗ type=${e.runtimeType}, error=$e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Alias for getUser for backwards compatibility.
  Future<UserModel?> getUserData(String uid) => getUser(uid);

  /// Merges [data] into `users/{uid}`.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    debugPrint(
        '[FirestoreService] updateUser() START → uid=$uid, fields=${data.keys.toList()}');
    try {
      await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
      debugPrint('[FirestoreService] updateUser() SUCCESS ✓ for uid=$uid');
    } on FirebaseException catch (e, st) {
      debugPrint(
          '[FirestoreService] updateUser() ERROR ✗ code=${e.code}, message=${e.message}');
      debugPrint(st.toString());
      rethrow;
    } catch (e, st) {
      debugPrint(
          '[FirestoreService] updateUser() UNEXPECTED ERROR ✗ type=${e.runtimeType}, error=$e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  // ─── Prediction History Methods ────────────────────────────────────────────

  Future<void> savePrediction(String uid, PredictionResult result) async {
    debugPrint(
        '[FirestoreService] savePrediction() START → uid=$uid, predId=${result.id}');
    try {
      final docRef = result.id.isEmpty
          ? _db.collection('users').doc(uid).collection('predictions').doc()
          : _db
              .collection('users')
              .doc(uid)
              .collection('predictions')
              .doc(result.id);
      await docRef.set(result.toMap());
      debugPrint('[FirestoreService] savePrediction() SUCCESS ✓');
    } on FirebaseException catch (e, st) {
      debugPrint(
          '[FirestoreService] savePrediction() ERROR ✗ code=${e.code}, message=${e.message}');
      debugPrint(st.toString());
      rethrow;
    } catch (e, st) {
      debugPrint(
          '[FirestoreService] savePrediction() UNEXPECTED ERROR ✗ type=${e.runtimeType}, error=$e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Stores complete user-isolated multi-modal record inside:
  /// `users/{uid}/predictions`, `users/{uid}/assessments`, `users/{uid}/retina_scans`,
  /// `users/{uid}/foot_scans`, and `users/{uid}/care_plans`.
  Future<void> saveMultiModalRecord({
    required String uid,
    required PredictionResult prediction,
    required Map<String, dynamic> assessmentPayload,
  }) async {
    debugPrint(
        '[FirestoreService] saveMultiModalRecord() START → uid=$uid, id=${prediction.id}');
    try {
      final userRef = _db.collection('users').doc(uid);
      final id = prediction.id.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : prediction.id;

      final batch = _db.batch();

      // 1. predictions subcollection
      batch.set(userRef.collection('predictions').doc(id), prediction.toMap());

      // 2. assessments subcollection
      batch.set(userRef.collection('assessments').doc(id), {
        'id': id,
        'date': prediction.date,
        'time': prediction.time,
        'assessmentScore': prediction.assessmentScore,
        'payload': assessmentPayload,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. retina_scans subcollection
      if (prediction.retinaImageUrl != null &&
          prediction.retinaImageUrl!.isNotEmpty) {
        batch.set(userRef.collection('retina_scans').doc(id), {
          'id': id,
          'date': prediction.date,
          'time': prediction.time,
          'result': prediction.retinaResult,
          'imageUrl': prediction.retinaImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. foot_scans subcollection
      if (prediction.footImageUrl != null &&
          prediction.footImageUrl!.isNotEmpty) {
        batch.set(userRef.collection('foot_scans').doc(id), {
          'id': id,
          'date': prediction.date,
          'time': prediction.time,
          'result': prediction.footResult,
          'imageUrl': prediction.footImageUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 5. care_plans subcollection
      batch.set(userRef.collection('care_plans').doc(id), {
        'id': id,
        'date': prediction.date,
        'time': prediction.time,
        'status': prediction.carePlanStatus,
        'recommendations': prediction.recommendations,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint(
          '[FirestoreService] saveMultiModalRecord() SUCCESS ✓ for uid=$uid');
    } catch (e, st) {
      debugPrint('[FirestoreService] saveMultiModalRecord() ERROR: $e');
      debugPrint(st.toString());
    }
  }

  /// Stream of user-specific prediction history from `users/{uid}/predictions`
  Stream<List<PredictionResult>> getPredictionHistory(String uid) {
    debugPrint('[FirestoreService] getPredictionHistory() STREAM → uid=$uid');
    return _db
        .collection('users')
        .doc(uid)
        .collection('predictions')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PredictionResult.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Fetches the single latest multi-modal prediction for dashboard display
  Future<PredictionResult?> getLatestMultiModalPrediction(String uid) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('predictions')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return PredictionResult.fromMap(
          snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      debugPrint('[FirestoreService] getLatestMultiModalPrediction ERROR: $e');
      return null;
    }
  }

  // ─── Individual Scan Records ──────────────────────────────────────────────

  /// Saves or overwrites `users/{uid}/retina` with the latest retina scan data.
  Future<void> saveRetinaRecord(String uid, String imageUrl, String prediction,
      {double? confidence,
      double? riskPercentage,
      String? riskLevel,
      String? severity}) async {
    debugPrint(
        '[FirestoreService] saveRetinaRecord() → uid=$uid, url=$imageUrl');
    try {
      await _db.collection('users').doc(uid).set({
        'retina': {
          'imageUrl': imageUrl,
          'prediction': prediction,
          if (confidence != null) 'confidence': confidence,
          if (riskPercentage != null) 'retina_risk_percentage': riskPercentage,
          if (riskLevel != null) 'riskLevel': riskLevel,
          if (severity != null) 'severity': severity,
          'uploadedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
      debugPrint('[FirestoreService] saveRetinaRecord() SUCCESS ✓');
    } catch (e) {
      debugPrint('[FirestoreService] saveRetinaRecord() ERROR: $e');
    }
  }

  /// Saves or overwrites `users/{uid}/foot` with the latest foot scan data.
  Future<void> saveFootRecord(String uid, String imageUrl, String prediction,
      {double? confidence,
      double? riskPercentage,
      String? riskLevel,
      String? severity}) async {
    debugPrint('[FirestoreService] saveFootRecord() → uid=$uid, url=$imageUrl');
    try {
      await _db.collection('users').doc(uid).set({
        'foot': {
          'imageUrl': imageUrl,
          'prediction': prediction,
          if (confidence != null) 'confidence': confidence,
          if (riskPercentage != null) 'foot_risk_percentage': riskPercentage,
          if (riskLevel != null) 'riskLevel': riskLevel,
          if (severity != null) 'severity': severity,
          'uploadedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
      debugPrint('[FirestoreService] saveFootRecord() SUCCESS ✓');
    } catch (e) {
      debugPrint('[FirestoreService] saveFootRecord() ERROR: $e');
    }
  }

  /// Retrieves the latest retina scan record from `users/{uid}` document.
  Future<Map<String, dynamic>?> getRetinaRecord(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final retina = data['retina'] as Map<String, dynamic>?;
      return retina;
    } catch (e) {
      debugPrint('[FirestoreService] getRetinaRecord ERROR: $e');
      return null;
    }
  }

  /// Retrieves the latest foot scan record from `users/{uid}` document.
  Future<Map<String, dynamic>?> getFootRecord(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final foot = data['foot'] as Map<String, dynamic>?;
      return foot;
    } catch (e) {
      debugPrint('[FirestoreService] getFootRecord ERROR: $e');
      return null;
    }
  }

  Future<void> saveAssessmentRecord(String uid, Map<String, dynamic> payload,
      Map<String, dynamic> result) async {
    await _db.collection('users').doc(uid).set({
      'assessment': {
        'payload': payload,
        'result': result,
        'savedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getAssessmentRecord(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    final assessment = data?['assessment'];
    return assessment is Map ? Map<String, dynamic>.from(assessment) : null;
  }
}
