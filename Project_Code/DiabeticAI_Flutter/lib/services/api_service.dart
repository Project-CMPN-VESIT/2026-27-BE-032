import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

class ApiService {
  late final Dio _dio;

  static String footPredictionError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final body = error.response?.data;
      final detail = body is Map && body['detail'] is String
          ? body['detail'] as String
          : null;
      if (statusCode == 429) {
        return detail ??
            'Foot screening is temporarily rate-limited. Please try again later.';
      }
      if (statusCode == 503) {
        return detail ??
            'Foot vision screening is unavailable. Check the backend model configuration.';
      }
      if (statusCode == 502) {
        return detail ??
            'The foot vision service could not complete the analysis. Please retry.';
      }
      if (detail != null) return detail;
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Foot screening timed out. Please try again.';
      }
    }
    return 'Foot screening failed: $error';
  }

  static String get resolvedBaseUrl {
    const url = AppConstants.baseUrl;
    if (url.contains("10.0.2.2")) {
      if (kIsWeb) return url.replaceAll("10.0.2.2", "localhost");
      try {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          return url.replaceAll("10.0.2.2", "127.0.0.1");
        }
      } catch (_) {}
    }
    return url;
  }

  ApiService() {
    final activeBaseUrl = resolvedBaseUrl;
    debugPrint(
        "🌐 [ApiService] Initializing Dio client with baseUrl = $activeBaseUrl");
    _dio = Dio(
      BaseOptions(
        baseUrl: activeBaseUrl,
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        headers: {
          'Accept': 'application/json',
        },
      ),
    )..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            debugPrint(
                "📡 [Dio HTTP REQUEST] ${options.method} ${options.uri}");
            debugPrint("📡 [Dio Headers] ${options.headers}");
            if (options.data is FormData) {
              final fd = options.data as FormData;
              debugPrint(
                  "📡 [Dio Payload] Multipart FormData (${fd.files.length} files: ${fd.files.map((f) => f.value.filename).join(', ')})");
            } else {
              debugPrint("📡 [Dio Payload] ${options.data}");
            }
            handler.next(options);
          },
          onResponse: (response, handler) {
            debugPrint(
                "✅ [Dio HTTP RESPONSE] ${response.statusCode} ${response.requestOptions.uri}");
            debugPrint("✅ [Dio Data] ${response.data}");
            handler.next(response);
          },
          onError: (error, handler) {
            debugPrint("❌ [Dio HTTP ERROR] ${error.requestOptions.uri}");
            debugPrint("❌ [Dio Message] ${error.message}");
            debugPrint("❌ [Dio Status] ${error.response?.statusCode}");
            debugPrint("❌ [Dio Response Data] ${error.response?.data}");
            handler.next(error);
          },
        ),
      );
  }

  /// Diabetes Assessment
  Future<Map<String, dynamic>> predictDiabetes(
      Map<String, dynamic> payload) async {
    debugPrint(
        "STEP 4: [ApiService] Sending Assessment request to ${AppConstants.baseUrl}/predict/assessment");
    final response = await _dio.post(
      "/predict/assessment",
      data: payload,
    );
    debugPrint(
        "STEP 5: [ApiService] Assessment response received from backend");
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Retina Prediction
  /// Sends Firebase download URL via JSON if available (starts with http),
  /// or uploads imageFile via multipart/form-data if Firebase upload failed.
  Future<Map<String, dynamic>> predictRetina({
    String? imageUrl,
    File? imageFile,
  }) async {
    debugPrint(
        "STEP 4: [ApiService] Sending Retina prediction request to ${AppConstants.baseUrl}/predict/retina");
    Response response;

    if (imageUrl != null && imageUrl.startsWith('http')) {
      debugPrint(
          "STEP 4a: [ApiService] Sending Firebase Download URL via JSON = $imageUrl");
      response = await _dio.post(
        "/predict/retina",
        data: {
          "imageUrl": imageUrl,
        },
        options: Options(contentType: 'application/json'),
      );
    } else if (imageFile != null && imageFile.existsSync()) {
      debugPrint(
          "STEP 4a: [ApiService] Uploading local image file via Multipart/Form-Data = ${imageFile.path}");
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last.split('\\').last,
        ),
      });
      response = await _dio.post(
        "/predict/retina",
        data: formData,
      );
    } else {
      throw ArgumentError(
          "predictRetina requires either a valid HTTP imageUrl or an existing imageFile");
    }

    debugPrint("STEP 5: [ApiService] Retina response received from backend");
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Foot Prediction
  /// Sends the selected image bytes to the backend for OpenCV analysis.
  /// The Firebase URL is saved separately for history and image display.
  Future<Map<String, dynamic>> predictFootUlcer({
    required File imageFile,
  }) async {
    debugPrint("==================================================");
    debugPrint("STEP 4: [ApiService] PREDICT FOOT CALL LOGS:");

    debugPrint("  - Local Image Path    : ${imageFile.path}");
    if (imageFile.existsSync()) {
      debugPrint("  - File Size           : ${imageFile.lengthSync()} bytes");
    }
    debugPrint("==================================================");

    if (!imageFile.existsSync()) {
      throw ArgumentError("predictFootUlcer requires an existing imageFile");
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last.split('\\').last,
      ),
    });
    final response = await _dio.post(
      "/predict/foot",
      data: formData,
    );

    debugPrint("STEP 5: [ApiService] Foot response received from backend");
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Final Prediction
  Future<Map<String, dynamic>> predictMultiModal(
      Map<String, dynamic> payload) async {
    debugPrint(
        "STEP 4: [ApiService] Sending Final Multi-Modal request to ${AppConstants.baseUrl}/predict/final");
    debugPrint("STEP 4a: Full Multi-Modal Payload = $payload");

    final response = await _dio.post(
      "/predict/final",
      data: payload,
      options: Options(contentType: 'application/json'),
    );

    debugPrint("STEP 5: [ApiService] Final response received from backend");
    return Map<String, dynamic>.from(response.data as Map);
  }
}
