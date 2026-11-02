Map<String, dynamic> buildAssessmentPayload({
  required bool highBp,
  required bool highChol,
  required bool cholCheck,
  required double bmi,
  required bool smoker,
  required bool stroke,
  required bool heartDisease,
  required int age,
  required int sex,
  required bool difficultyWalking,
  int? familyHistory,
  int? familyMembersCount,
  String? familyDiabetesType,
  int? physicalActivity,
  int? waterIntake,
  int? fruitIntake,
  int? vegetableIntake,
  String? sleepDuration,
  int? stressLevel,
  int? physicalHealthRating,
  int? mentalHealthRating,
}) {
  int? sleepDurationCategory;
  if (sleepDuration != null) {
    sleepDurationCategory = switch (sleepDuration) {
      '<6 hrs' => 1,
      '6-8 hrs' => 2,
      '>8 hrs' => 3,
      _ => throw ArgumentError.value(
          sleepDuration, 'sleepDuration', 'Unsupported sleep duration.'),
    };
  }

  final hasFamilyHistory = familyHistory != null && familyHistory > 0;
  return {
    'HighBP': highBp ? 1 : 0,
    'HighChol': highChol ? 1 : 0,
    'CholCheck': cholCheck ? 1 : 0,
    'BMI': bmi,
    'Smoker': smoker ? 1 : 0,
    'Stroke': stroke ? 1 : 0,
    'HeartDiseaseorAttack': heartDisease ? 1 : 0,
    'Age': age,
    'Sex': sex,
    'DiffWalk': difficultyWalking ? 1 : 0,
    if (familyHistory != null) 'FamilyHistory': familyHistory,
    if (hasFamilyHistory && familyMembersCount != null)
      'FamilyMembersCount': familyMembersCount,
    if (hasFamilyHistory && familyDiabetesType != null)
      'FamilyDiabetesType': familyDiabetesType,
    if (physicalActivity != null) 'PhysActivity': physicalActivity,
    if (waterIntake != null) 'WaterIntake': waterIntake,
    if (fruitIntake != null) 'Fruits': fruitIntake,
    if (vegetableIntake != null) 'Veggies': vegetableIntake,
    if (sleepDurationCategory != null)
      'SleepDuration': sleepDurationCategory,
    if (stressLevel != null) 'StressLevel': stressLevel,
    if (physicalHealthRating != null)
      'PhysHlthRating': physicalHealthRating,
    if (mentalHealthRating != null) 'MentHlthRating': mentalHealthRating,
  };
}
