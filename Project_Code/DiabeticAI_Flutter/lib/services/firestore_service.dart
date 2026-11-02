import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/prediction_result.dart';
import '../models/user_model.dart';

/// Handles Cloud Firestore database operations with debug logging and robust error handling.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _requireAuthenticatedUid(String uid) {
    if (uid.isEmpty || FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError(
        'Sign in with the account that owns this data before continuing.',
      );
    }
  }

  static String userFacingError(Object error, {required String operation}) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'Firestore denied permission to $operation. Please sign in again. '
          'If the problem continues, ask the administrator to deploy the '
          'project Firestore security rules.';
    }
    if (error is StateError) return error.message;
    return '$operation failed: $error';
  }

  // ─── User Document Methods ────────────────────────────────────────────────

  /// Creates or updates a user document at `users/{uid}`.
  /// Uses [SetOptions.merge] to ensure idempotency.
  Future<void> createUser({
    required String uid,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    _requireAuthenticatedUid(uid);
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
    _requireAuthenticatedUid(uid);
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
    _requireAuthenticatedUid(uid);
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
    _requireAuthenticatedUid(uid);
    if (result.id.isEmpty) {
      throw ArgumentError.value(result.id, 'result.id', 'Must not be empty.');
    }
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
      await docRef.set({
        ...result.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
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
    _requireAuthenticatedUid(uid);
    if (prediction.id.isEmpty) {
      throw ArgumentError.value(
          prediction.id, 'prediction.id', 'Must not be empty.');
    }
    debugPrint(
        '[FirestoreService] saveMultiModalRecord() START → uid=$uid, id=${prediction.id}');
    try {
      final userRef = _db.collection('users').doc(uid);
      final id = prediction.id.isEmpty
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : prediction.id;

      final batch = _db.batch();

      // 1. predictions subcollection
      batch.set(userRef.collection('predictions').doc(id), {
        ...prediction.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

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
          if (prediction.footFinding != null) 'finding': prediction.footFinding,
          if (prediction.footReason != null) 'reason': prediction.footReason,
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
      rethrow;
    }
  }

  /// Stream of user-specific prediction history from `users/{uid}/predictions`
  Stream<List<PredictionResult>> getPredictionHistory(String uid) {
    _requireAuthenticatedUid(uid);
    debugPrint('[FirestoreService] getPredictionHistory() STREAM → uid=$uid');
    return _db
        .collection('users')
        .doc(uid)
        .collection('predictions')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PredictionResult.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<int> countPredictionHistory(String uid) async {
    _requireAuthenticatedUid(uid);
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('predictions')
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> deletePredictionHistory(String uid) async {
    _requireAuthenticatedUid(uid);
    final predictions =
        _db.collection('users').doc(uid).collection('predictions');

    while (true) {
      final snapshot = await predictions.limit(450).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _db.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < 450) return;
    }
  }

  /// Fetches the single latest multi-modal prediction for dashboard display
  Future<PredictionResult?> getLatestMultiModalPrediction(String uid) async {
    _requireAuthenticatedUid(uid);
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('predictions')
          .where('type', isEqualTo: PredictionType.multiModalCombined.name)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return PredictionResult.fromMap(
          snapshot.docs.first.data(), snapshot.docs.first.id);
    } catch (e) {
      debugPrint('[FirestoreService] getLatestMultiModalPrediction ERROR: $e');
      rethrow;
    }
  }

  // ─── Individual Scan Records ──────────────────────────────────────────────

  /// Saves or overwrites `users/{uid}/retina` with the latest retina scan data.
  Future<void> saveRetinaRecord(String uid, String imageUrl, String prediction,
      {double? confidence,
      double? riskPercentage,
      String? riskLevel,
      String? severity}) async {
    _requireAuthenticatedUid(uid);
    debugPrint(
        '[FirestoreService] saveRetinaRecord() → uid=$uid, url=$imageUrl');
    await _db.collection('users').doc(uid).set({
      'retina': {
        'imageUrl': imageUrl,
        'prediction': prediction,
        'confidence': confidence ?? FieldValue.delete(),
        'retina_risk_percentage': riskPercentage ?? FieldValue.delete(),
        'riskLevel': riskLevel ?? FieldValue.delete(),
        'severity': severity ?? FieldValue.delete(),
        'uploadedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
    debugPrint('[FirestoreService] saveRetinaRecord() SUCCESS ✓');
  }

  /// Saves or overwrites `users/{uid}/foot` with the latest foot scan data.
  Future<void> saveFootRecord(String uid, String imageUrl, String prediction,
      {double? confidence,
      double? riskPercentage,
      String? riskLevel,
      String? severity,
      String? finding,
      String? description,
      String? reason}) async {
    _requireAuthenticatedUid(uid);
    debugPrint('[FirestoreService] saveFootRecord() → uid=$uid, url=$imageUrl');
    await _db.collection('users').doc(uid).set({
      'foot': {
        'imageUrl': imageUrl,
        'prediction': prediction,
        'finding': finding ?? FieldValue.delete(),
        'description': description ?? FieldValue.delete(),
        'reason': reason ?? FieldValue.delete(),
        'confidence': confidence ?? FieldValue.delete(),
        'foot_risk_percentage': riskPercentage ?? FieldValue.delete(),
        'riskLevel': riskLevel ?? FieldValue.delete(),
        'severity': severity ?? FieldValue.delete(),
        'uploadedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
    debugPrint('[FirestoreService] saveFootRecord() SUCCESS ✓');
  }

  /// Retrieves the latest retina scan record from `users/{uid}` document.
  Future<Map<String, dynamic>?> getRetinaRecord(String uid) async {
    _requireAuthenticatedUid(uid);
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final retina = data['retina'] as Map<String, dynamic>?;
      return retina;
    } catch (e) {
      debugPrint('[FirestoreService] getRetinaRecord ERROR: $e');
      rethrow;
    }
  }

  /// Retrieves the latest foot scan record from `users/{uid}` document.
  Future<Map<String, dynamic>?> getFootRecord(String uid) async {
    _requireAuthenticatedUid(uid);
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final foot = data['foot'] as Map<String, dynamic>?;
      return foot;
    } catch (e) {
      debugPrint('[FirestoreService] getFootRecord ERROR: $e');
      rethrow;
    }
  }

  Future<void> saveAssessmentRecord(String uid, Map<String, dynamic> payload,
      Map<String, dynamic> result) async {
    _requireAuthenticatedUid(uid);
    await _db.collection('users').doc(uid).set({
      'assessment': {
        'payload': payload,
        'result': result,
        'savedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  Future<void> saveAssessmentAndPrediction(
    String uid,
    Map<String, dynamic> payload,
    Map<String, dynamic> result,
    PredictionResult prediction,
  ) async {
    _requireAuthenticatedUid(uid);
    if (prediction.id.isEmpty) {
      throw ArgumentError.value(
          prediction.id, 'prediction.id', 'Must not be empty.');
    }

    final userRef = _db.collection('users').doc(uid);
    final batch = _db.batch();
    batch.set(
      userRef,
      {
        'assessment': {
          'payload': payload,
          'result': result,
          'savedAt': FieldValue.serverTimestamp(),
        }
      },
      SetOptions(merge: true),
    );
    batch.set(
      userRef.collection('predictions').doc(prediction.id),
      {
        ...prediction.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  Future<Map<String, dynamic>?> getAssessmentRecord(String uid) async {
    _requireAuthenticatedUid(uid);
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    final assessment = data?['assessment'];
    return assessment is Map ? Map<String, dynamic>.from(assessment) : null;
  }
}
