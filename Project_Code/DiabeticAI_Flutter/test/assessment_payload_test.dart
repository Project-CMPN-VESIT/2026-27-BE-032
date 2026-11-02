import 'package:flutter_test/flutter_test.dart';
import 'package:diabeticai_flutter/utils/assessment_payload.dart';

void main() {
  group('assessment payload', () {
    test('includes required answers without fabricated optional values', () {
      final payload = buildAssessmentPayload(
        highBp: false,
        highChol: true,
        cholCheck: false,
        bmi: 24.7,
        smoker: false,
        stroke: false,
        heartDisease: false,
        age: 5,
        sex: 0,
        difficultyWalking: false,
      );

      expect(payload, {
        'HighBP': 0,
        'HighChol': 1,
        'CholCheck': 0,
        'BMI': 24.7,
        'Smoker': 0,
        'Stroke': 0,
        'HeartDiseaseorAttack': 0,
        'Age': 5,
        'Sex': 0,
        'DiffWalk': 0,
      });
    });

    test('maps entered optional values and omits unrelated blank values', () {
      final payload = buildAssessmentPayload(
        highBp: false,
        highChol: false,
        cholCheck: true,
        bmi: 26.2,
        smoker: true,
        stroke: false,
        heartDisease: false,
        age: 7,
        sex: 1,
        difficultyWalking: true,
        familyHistory: 2,
        familyMembersCount: 1,
        familyDiabetesType: 'Type 2',
        physicalActivity: 0,
        sleepDuration: '<6 hrs',
        stressLevel: 3,
      );

      expect(payload['FamilyHistory'], 2);
      expect(payload['FamilyMembersCount'], 1);
      expect(payload['FamilyDiabetesType'], 'Type 2');
      expect(payload['PhysActivity'], 0);
      expect(payload['SleepDuration'], 1);
      expect(payload['StressLevel'], 3);
      expect(payload.containsKey('Education'), isFalse);
      expect(payload.containsKey('Income'), isFalse);
      expect(payload.containsKey('AnyHealthcare'), isFalse);
      expect(payload.containsKey('FamilyMembersCount'), isTrue);
      expect(payload.containsKey('JunkFood'), isFalse);
    });

    test('does not retain family details when family history is none', () {
      final payload = buildAssessmentPayload(
        highBp: false,
        highChol: false,
        cholCheck: false,
        bmi: 22,
        smoker: false,
        stroke: false,
        heartDisease: false,
        age: 4,
        sex: 1,
        difficultyWalking: false,
        familyHistory: 0,
        familyMembersCount: 2,
        familyDiabetesType: 'Type 1',
      );

      expect(payload['FamilyHistory'], 0);
      expect(payload.containsKey('FamilyMembersCount'), isFalse);
      expect(payload.containsKey('FamilyDiabetesType'), isFalse);
    });
  });
}
