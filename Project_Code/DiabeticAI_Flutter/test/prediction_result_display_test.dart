import 'package:diabeticai_flutter/models/prediction_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('screening result display mapping', () {
    test('combined record shares overall and individual scan statuses', () {
      final result = PredictionResult.fromMap(
        {
          'type': 'multiModalCombined',
          'riskLevel': 'borderline',
          'predictionLabel': 'Borderline / Further Assessment',
          'assessmentScore': 5,
          'retinaResult': 'Healthy Fundus - No Retinopathy',
          'footResult': 'INCONCLUSIVE',
          'footFinding': 'Foot status could not be determined reliably.',
        },
        'combined-screening',
      );

      expect(result.overallStatusLabel, 'BORDERLINE');
      expect(result.historyStatusLabel, result.overallStatusLabel);
      expect(result.retinaStatusLabel, 'NORMAL');
      expect(result.footStatusLabel, 'INCONCLUSIVE');
      expect(result.assessmentScore, 5);
    });

    test('legacy result fields retain the same canonical display labels', () {
      final result = PredictionResult.fromMap(
        {
          'type': 'multiModalCombined',
          'risk_level': 'borderline',
          'prediction': 'Borderline / Further Assessment',
          'assessment_score': 5,
          'retina_result': 'Normal',
          'foot_result': 'Mild Finding Detected',
          'source': 'deterministic-image-processing-heuristic',
        },
        'legacy-combined-screening',
      );

      expect(result.overallStatusLabel, 'BORDERLINE');
      expect(result.historyStatusLabel, 'BORDERLINE');
      expect(result.retinaStatusLabel, 'NORMAL');
      expect(result.footStatusLabel, 'INCONCLUSIVE');
      expect(result.assessmentScore, 5);
    });

    test('a legacy heuristic mark is displayed as inconclusive', () {
      final result = PredictionResult.fromMap(
        {
          'type': 'footUlcerScan',
          'riskLevel': 'borderline',
          'predictionLabel': 'Mild Finding Detected',
          'footResult': 'A visible mark or skin change is detected.',
          'source': 'deterministic-image-processing-heuristic',
        },
        'foot-screening',
      );

      expect(result.historyStatusLabel, 'INCONCLUSIVE');
    });

    test('a severe foot finding remains distinct from normal and unknown', () {
      final result = PredictionResult.fromMap(
        {
          'type': 'footUlcerScan',
          'riskLevel': 'borderline',
          'predictionLabel': 'SEVERE FINDING',
          'footResult': 'A prominent suspicious finding requires review.',
          'source': 'future-verified-classifier',
        },
        'severe-foot-screening',
      );

      expect(result.historyStatusLabel, 'SEVERE FINDING');
    });

    test('mild foot findings remain individual scan statuses', () {
      final result = PredictionResult.fromMap(
        {
          'type': 'footUlcerScan',
          'riskLevel': 'inconclusive',
          'predictionLabel': 'MILD FINDING',
          'footResult': 'A minor visible finding requires further assessment.',
        },
        'mild-foot-screening',
      );

      expect(result.historyStatusLabel, 'MILD FINDING');
    });

    test('model probabilities and valid scan confidence remain distinct', () {
      final result = PredictionResult.fromMap(
        {
          'type': 'multiModalCombined',
          'riskLevel': 'borderline',
          'predictionLabel': 'Borderline / Further Assessment',
          'assessment_score': 58,
          'assessment_class_probabilities': {
            'normal': 42,
            'borderline': null,
            'diabetes': null,
            'combined_prediabetes_diabetes': 58,
          },
          'assessment_explanation': 'Binary-model screening output.',
          'retina_result': 'Mild Retinopathy',
          'retina_confidence': 91.2,
          'foot_result': 'MILD FINDING',
          'foot_confidence': null,
        },
        'combined-screening',
      );

      expect(result.assessmentScore, 58);
      expect(result.assessmentClassProbabilities['normal'], 42);
      expect(result.assessmentClassProbabilities['borderline'], isNull);
      expect(
        result.assessmentClassProbabilities['combined_prediabetes_diabetes'],
        58,
      );
      expect(result.assessmentExplanation, 'Binary-model screening output.');
      expect(result.retinaConfidencePercentage, 91.2);
      expect(result.footConfidencePercentage, isNull);
      expect(
        result.toMap()['assessmentClassProbabilities'],
        result.assessmentClassProbabilities,
      );
    });
  });
}
