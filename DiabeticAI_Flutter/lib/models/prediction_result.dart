enum RiskLevel { healthy, prediabetic, diabetic, highRisk }

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
  final RiskLevel riskLevel;
  final String predictionLabel;
  final double riskPercentage;
  final double confidencePercentage;
  final double assessmentScore;
  final double? retinaRiskPercentage;
  final double? footRiskPercentage;
  final String retinaResult;
  final String footResult;
  final String carePlanStatus;
  final String? imageUrl;
  final String? retinaImageUrl;
  final String? footImageUrl;
  final String? nextScreeningDate;
  final List<String> recommendations;
  final String source;

  PredictionResult({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.time = '12:00 PM',
    required this.riskLevel,
    required this.predictionLabel,
    required this.riskPercentage,
    required this.confidencePercentage,
    this.assessmentScore = 0.0,
    this.retinaRiskPercentage,
    this.footRiskPercentage,
    this.retinaResult = 'Not Performed',
    this.footResult = 'Not Performed',
    this.carePlanStatus = 'Active Care Plan Generated',
    this.imageUrl,
    this.retinaImageUrl,
    this.footImageUrl,
    this.nextScreeningDate,
    this.recommendations = const [],
    this.source = 'backend',
  });

  factory PredictionResult.fromMap(Map<String, dynamic> map, String id) {
    final double riskPct =
        (map['risk_percentage'] ?? map['riskPercentage'] as num?)?.toDouble() ??
            0.0;
    return PredictionResult(
      id: id,
      type: PredictionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PredictionType.multiModalCombined,
      ),
      title: map['title'] ?? 'Multi-Modal Diabetes AI Assessment',
      date: map['date'] ?? '',
      time: map['time'] ?? '12:00 PM',
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == map['riskLevel'] || e.name == map['risk_level'],
        orElse: () => RiskLevel.healthy,
      ),
      predictionLabel: map['predictionLabel'] ?? map['prediction'] ?? '',
      riskPercentage: riskPct,
      confidencePercentage:
          (map['confidencePercentage'] ?? map['confidence'] as num?)?.toDouble() ?? 0.0,
      assessmentScore: (map['assessmentScore'] ?? map['assessment_score'] as num?)?.toDouble() ?? 0.0,
      retinaRiskPercentage:
          (map['retina_risk_percentage'] ?? map['retinaRiskPercentage'] as num?)
              ?.toDouble(),
      footRiskPercentage:
          (map['foot_risk_percentage'] ?? map['footRiskPercentage'] as num?)
              ?.toDouble(),
      retinaResult: map['retinaResult'] ?? map['retina_result'] ?? 'Normal',
      footResult: map['footResult'] ?? map['foot_result'] ?? 'Normal',
      carePlanStatus: map['carePlanStatus'] ?? 'Active Care Plan',
      imageUrl: map['imageUrl'] as String?,
      retinaImageUrl: map['retinaImageUrl'] as String?,
      footImageUrl: map['footImageUrl'] as String?,
      nextScreeningDate: map['nextScreeningDate'] as String?,
      recommendations: List<String>.from(map['recommendations'] ?? map['care_plan'] ?? []),
      source: map['source'] ?? 'backend',
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
      'retina_risk_percentage': retinaRiskPercentage,
      'foot_risk_percentage': footRiskPercentage,
      'retinaResult': retinaResult,
      'footResult': footResult,
      'carePlanStatus': carePlanStatus,
      'imageUrl': imageUrl,
      'retinaImageUrl': retinaImageUrl,
      'footImageUrl': footImageUrl,
      'nextScreeningDate': nextScreeningDate,
      'recommendations': recommendations,
      'source': source,
    };
  }

  static double retinaRiskFor(String prediction, double confidence) {
    final text = prediction.toLowerCase();
    return text.contains('severe')
        ? 85
        : (text.contains('moderate') ? 60 : (text.contains('mild') ? 30 : 8));
  }

  static double footRiskFor(String prediction, double confidence) {
    final match =
        RegExp(r'grade\s*([0-3])', caseSensitive: false).firstMatch(prediction);
    final grade = int.tryParse(match?.group(1) ?? '0') ?? 0;
    return const [8.0, 30.0, 60.0, 85.0][grade.clamp(0, 3)];
  }
}
