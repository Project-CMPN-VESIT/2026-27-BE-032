import 'dart:io';
import 'package:flutter/foundation.dart';

enum ScanImageType { retina, foot }

class ImageValidationResult {
  final bool isValid;
  final String errorMessage;

  const ImageValidationResult({required this.isValid, required this.errorMessage});
}

class ImageValidationService {
  static Future<ImageValidationResult> validateImage(
    File imageFile,
    ScanImageType expectedType,
  ) async {
    try {
      final fileName = imageFile.path.toLowerCase();

      // Check obvious invalid keywords in filename/path (documents, selfies, pets, landscapes)
      final invalidGeneral = [
        'selfie',
        'doc',
        'document',
        'pdf',
        'passport',
        'receipt',
        'card',
        'pet',
        'cat',
        'dog',
        'landscape',
        'car',
        'avatar',
      ];
      for (final kw in invalidGeneral) {
        if (fileName.contains(kw)) {
          final msg = expectedType == ScanImageType.retina
              ? 'Please upload a retinal fundus image.'
              : 'Please upload a diabetic foot image.';
          return ImageValidationResult(isValid: false, errorMessage: msg);
        }
      }

      if (expectedType == ScanImageType.retina) {
        // Reject foot/skin images uploaded as retina
        if (fileName.contains('foot') || fileName.contains('toe') || fileName.contains('ulcer') || fileName.contains('wound')) {
          return const ImageValidationResult(
            isValid: false,
            errorMessage: 'Please upload a retinal fundus image.',
          );
        }
      } else if (expectedType == ScanImageType.foot) {
        // Reject retina/eye images uploaded as foot
        if (fileName.contains('retina') || fileName.contains('fundus') || fileName.contains('eye') || fileName.contains('optic')) {
          return const ImageValidationResult(
            isValid: false,
            errorMessage: 'Please upload a diabetic foot image.',
          );
        }
      }

      // Ensure file exists and has valid non-corrupt byte length
      final bytes = await imageFile.readAsBytes();
      if (bytes.length < 1024) {
        final msg = expectedType == ScanImageType.retina
            ? 'Please upload a retinal fundus image.'
            : 'Please upload a diabetic foot image.';
        return ImageValidationResult(isValid: false, errorMessage: msg);
      }

      return const ImageValidationResult(isValid: true, errorMessage: '');
    } catch (e) {
      debugPrint('[ImageValidationService] Error validating image: $e');
      return const ImageValidationResult(isValid: true, errorMessage: '');
    }
  }
}
