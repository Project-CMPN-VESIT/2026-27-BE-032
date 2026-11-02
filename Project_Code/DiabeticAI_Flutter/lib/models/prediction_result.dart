import 'package:cloud_firestore/cloud_firestore.dart';

enum RiskLevel {
  healthy,
  borderline,
  prediabetic,
  diabetic,
  highRisk,
  inconclusive
}

enum PredictionType {
  diabetesAssessment,
  footUlcerScan,
  retinaScan,
  multiModalCombined
}

class PredictionResult {
  final String id;
  final PredictionType type;
  final String title;
  final String date;
  final String time;
  final DateTime? createdAt;
  final RiskLevel riskLevel;
  final String predictionLabel;
  final double? riskPercentage;
  final double? confidencePercentage;
  final double? assessmentScore;
  final Map<String, double?> assessmentClassProbabilities;
  final String? assessmentExplanation;
  final String? assessmentProbabilityCalibration;
  final double? retinaRiskPercentage;
  final double? retinaConfidencePercentage;
  final double? footRiskPercentage;
  final double? footConfidencePercentage;
  final String retinaResult;
  final String footResult;
  final String? footFinding;
  final String? footReason;
  final String carePlanStatus;
  final String? imageUrl;
  final String? retinaImageUrl;
  final String? footImageUrl;
  final String? nextScreeningDate;
  final List<String> recommendations;
  final String source;

  String get overallStatusLabel => switch (riskLevel) {
        RiskLevel.healthy => 'NORMAL',
        RiskLevel.borderline => 'BORDERLINE',
        RiskLevel.prediabetic => 'PREDIABETIC',
        RiskLevel.diabetic => 'DIABETIC',
        RiskLevel.highRisk => 'HIGH RISK',
        RiskLevel.inconclusive => 'INCONCLUSIVE',
      };

  String get retinaStatusLabel {
    final value = retinaResult.trim().isNotEmpty
        ? retinaResult.trim()
        : (type == PredictionType.retinaScan ? predictionLabel.trim() : '');
    final normalized = value.toLowerCase();
    if (normalized == 'normal' ||
        normalized == 'no retinopathy' ||
        normalized.contains('healthy fundus') ||
        normalized.contains('no retinopathy')) {
      return 'NORMAL';
    }
    return value.toUpperCase();
  }

  String get footStatusLabel {
    String? canonicalStatus(String value) {
      return switch (value.trim().toLowerCase()) {
        'normal' || 'grade 0 normal' => 'NORMAL',
        'ulcer suspected' => 'ULCER SUSPECTED',
        'mild finding' => 'MILD FINDING',
        'severe finding' => 'SEVERE FINDING',
        'mild finding detected' => 'INCONCLUSIVE',
        'inconclusive' => 'INCONCLUSIVE',
        _ => null,
      };
    }

    final storedResult = footResult.trim();
    final prediction = predictionLabel.trim();
    final canonical =
        canonicalStatus(storedResult) ?? canonicalStatus(prediction);
    if (canonical != null) return canonical;

    final value = storedResult.isNotEmpty ? storedResult : prediction;
    return value.toUpperCase();
  }

  String get historyStatusLabel => switch (type) {
        PredictionType.multiModalCombined => overallStatusLabel,
        PredictionType.footUlcerScan => footStatusLabel,
        PredictionType.retinaScan => retinaStatusLabel,
        PredictionType.diabetesAssessment => overallStatusLabel,
      };

  PredictionResult({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.time = '',
    this.createdAt,
    required this.riskLevel,
    required this.predictionLabel,
    required this.riskPercentage,
    required this.confidencePercentage,
    this.assessmentScore,
    this.assessmentClassProbabilities = const {},
    this.assessmentExplanation,
    this.assessmentProbabilityCalibration,
    this.retinaRiskPercentage,
    this.retinaConfidencePercentage,
    this.footRiskPercentage,
    this.footConfidencePercentage,
    this.retinaResult = '',
    this.footResult = '',
    this.footFinding,
    this.footReason,
    this.carePlanStatus = '',
    this.imageUrl,
    this.retinaImageUrl,
    this.footImageUrl,
    this.nextScreeningDate,
    this.recommendations = const [],
    this.source = '',
  });

  factory PredictionResult.fromMap(Map<String, dynamic> map, String id) {
    double? numberFrom(Object? value) {
      if (value is! num || !value.isFinite || value < 0 || value > 100) {
        return null;
      }
      return value.toDouble();
    }

    Map<String, double?> probabilitiesFrom(Object? value) {
      if (value is! Map) return const {};
      return {
        for (final entry in value.entries)
          if (entry.key is String)
            entry.key as String: entry.value == null
                ? null
                : numberFrom(entry.value),
      };
    }

    DateTime? timestampFrom(Object? value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final rawType = map['type'];
    final rawRiskLevel = map['riskLevel'] ?? map['risk_level'];
    final rawRecommendations = map['recommendations'] ?? map['care_plan'];
    return PredictionResult(
      id: id,
      type: PredictionType.values.firstWhere(
        (e) => e.name == rawType,
        orElse: () => PredictionType.multiModalCombined,
      ),
      title: map['title'] is String ? map['title'] as String : '',
      date: map['date'] is String ? map['date'] as String : '',
      time: map['time'] is String ? map['time'] as String : '',
      createdAt: timestampFrom(map['createdAt']),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == rawRiskLevel,
        orElse: () => RiskLevel.inconclusive,
      ),
      predictionLabel: map['predictionLabel'] is String
          ? map['predictionLabel'] as String
          : (map['prediction'] is String ? map['prediction'] as String : ''),
      riskPercentage:
          numberFrom(map['risk_percentage'] ?? map['riskPercentage']),
      confidencePercentage:
          numberFrom(map['confidencePercentage'] ?? map['confidence']),
      assessmentScore:
          numberFrom(map['assessmentScore'] ?? map['assessment_score']),
      assessmentClassProbabilities: probabilitiesFrom(
        map['assessmentClassProbabilities'] ??
            map['assessment_class_probabilities'],
      ),
      assessmentExplanation:
          map['assessmentExplanation'] is String
              ? map['assessmentExplanation'] as String
              : (map['assessment_explanation'] is String
                  ? map['assessment_explanation'] as String
                  : null),
      assessmentProbabilityCalibration:
          map['assessmentProbabilityCalibration'] is String
              ? map['assessmentProbabilityCalibration'] as String
              : (map['assessment_probability_calibration'] is String
                  ? map['assessment_probability_calibration'] as String
                  : null),
      retinaRiskPercentage: numberFrom(
          map['retina_risk_percentage'] ?? map['retinaRiskPercentage']),
      retinaConfidencePercentage:
          numberFrom(map['retina_confidence'] ?? map['retinaConfidence']),
      footRiskPercentage:
          numberFrom(map['foot_risk_percentage'] ?? map['footRiskPercentage']),
      footConfidencePercentage:
          numberFrom(map['foot_confidence'] ?? map['footConfidence']),
      retinaResult: map['retinaResult'] is String
          ? map['retinaResult'] as String
          : (map['retina_result'] is String
              ? map['retina_result'] as String
              : ''),
      footResult: map['footResult'] is String
          ? map['footResult'] as String
          : (map['foot_result'] is String ? map['foot_result'] as String : ''),
      footFinding:
          map['footFinding'] is String ? map['footFinding'] as String : null,
      footReason:
          map['footReason'] is String ? map['footReason'] as String : null,
      carePlanStatus: map['carePlanStatus'] is String
          ? map['carePlanStatus'] as String
          : '',
      imageUrl: map['imageUrl'] is String ? map['imageUrl'] as String : null,
      retinaImageUrl: map['retinaImageUrl'] is String
          ? map['retinaImageUrl'] as String
          : null,
      footImageUrl:
          map['footImageUrl'] is String ? map['footImageUrl'] as String : null,
      nextScreeningDate: map['nextScreeningDate'] is String
          ? map['nextScreeningDate'] as String
          : null,
      recommendations: rawRecommendations is Iterable
          ? rawRecommendations.whereType<String>().toList()
          : const [],
      source: map['source'] is String ? map['source'] as String : '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'title': title,
      'date': date,
      'time': time,
      'riskLevel': riskLevel.name,
      'risk_level': riskLevel.name,
      'predictionLabel': predictionLabel,
      'prediction': predictionLabel,
      'riskPercentage': riskPercentage,
      'risk_percentage': riskPercentage,
      'confidencePercentage': confidencePercentage,
      'confidence': confidencePercentage,
      'assessmentScore': assessmentScore,
      'assessmentClassProbabilities': assessmentClassProbabilities,
      'assessmentExplanation': assessmentExplanation,
      'assessmentProbabilityCalibration': assessmentProbabilityCalibration,
      'retina_risk_percentage': retinaRiskPercentage,
      'retinaConfidence': retinaConfidencePercentage,
      'foot_risk_percentage': footRiskPercentage,
      'footConfidence': footConfidencePercentage,
      'retinaResult': retinaResult,
      'footResult': footResult,
      'footFinding': footFinding,
      'footReason': footReason,
      'carePlanStatus': carePlanStatus,
      'imageUrl': imageUrl,
      'retinaImageUrl': retinaImageUrl,
      'footImageUrl': footImageUrl,
      'nextScreeningDate': nextScreeningDate,
      'recommendations': recommendations,
      'source': source,
    };
  }
}
