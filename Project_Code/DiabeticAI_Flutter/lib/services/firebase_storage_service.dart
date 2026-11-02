import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageUploadException implements Exception {
  final String message;
  FirebaseStorageUploadException(this.message);

  @override
  String toString() => 'FirebaseStorageUploadException: $message';
}

class FirebaseStorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads an image file to Firebase Storage under `users/{uid}/{folder}/{timestamp}.jpg`
  /// and returns the public Firebase Storage download URL.
  Future<String> uploadImage(
    File imageFile, {
    required String folder,
    required String uid,
  }) async {
    if (!imageFile.existsSync()) {
      throw FirebaseStorageUploadException('Selected image file does not exist.');
    }

    final userUid = uid.isEmpty ? 'anonymous' : uid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = imageFile.path.split('.').last.toLowerCase();
    final validExtension = ['jpg', 'jpeg', 'png', 'webp'].contains(extension) ? extension : 'jpg';
    final fileName = '${folder}_${userUid}_$timestamp.$validExtension';

    final storagePath = 'users/$userUid/$folder/$fileName';
    debugPrint('[FirebaseStorage] ─── UPLOAD START ───────────────────────────────');
    debugPrint('[FirebaseStorage] Target Path: $storagePath');

    try {
      final ref = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/$validExtension',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'uploadedBy': userUid,
        },
      );

      final uploadTask = ref.putFile(imageFile, metadata);
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw FirebaseStorageUploadException(
          'Firebase Storage upload timed out after 5s. Fast-falling back to direct API upload.',
        ),
      );
      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw FirebaseStorageUploadException(
          'Firebase Storage getDownloadURL timed out after 5s. Fast-falling back to direct API upload.',
        ),
      );

      debugPrint('[FirebaseStorage] ✅ UPLOAD SUCCESS: $downloadUrl');
      return downloadUrl;
    } on FirebaseStorageUploadException {
      rethrow;
    } on FirebaseException catch (e) {
      debugPrint('[FirebaseStorage] ❌ UPLOAD FAILED: ${e.code} - ${e.message}');
      throw FirebaseStorageUploadException(
          'Firebase Storage upload failed (${e.code}): ${e.message}');
    } catch (e) {
      debugPrint('[FirebaseStorage] ❌ UNEXPECTED ERROR: $e');
      throw FirebaseStorageUploadException('Firebase Storage upload failed: $e');
    }
  }
}
