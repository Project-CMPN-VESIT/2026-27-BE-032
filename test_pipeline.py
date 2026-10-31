import sys
from pathlib import Path

# Add project root to sys.path
sys.path.append(r"c:\Capstone Project\option2")

from backend.models.registry import ModelRegistry
from backend.services.prediction_service import (
    assess_diabetes,
    predict_retina,
    predict_foot,
    predict_final,
)

def run_test():
    print("==================================================")
    print("END-TO-END PIPELINE DIAGNOSTIC TEST")
    print("==================================================")

    # 1. Initialize Registry & Load Models
    registry = ModelRegistry()
    registry.load_all()

    # 2. Test Assessment Endpoint
    assessment_payload = {
        "HighBP": 1,
        "HighChol": 1,
        "BMI": 32.5,
        "Stroke": 0,
        "HeartDiseaseorAttack": 1,
        "Age": 8,
        "DiffWalk": 1,
        "FamilyHistory": 1,
        "FamilyMembersCount": 2,
        "StressLevel": 4,
        "JunkFood": 1,
        "SugaryDrinks": 1,
        "SittingHours": 4,
        "SleepDuration": 2,
        "PhysHlthRating": 3,
        "MentHlthRating": 3,
    }
    assessment_res = assess_diabetes(assessment_payload, model=registry.assessment_model)
    print("\nAssessment Result:", assessment_res["prediction"], f"({assessment_res['risk_percentage']}%)")

    # 3. Test Retina Model with online sample retinal fundus image
    sample_retina_url = "https://upload.wikimedia.org/wikipedia/commons/4/42/Fundus_photograph_showing_severe_diabetic_retinopathy.jpg"
    print(f"\nTesting Retina Model with URL: {sample_retina_url}")
    retina_res = predict_retina(sample_retina_url, model=registry.retina_model)
    print("Retina Prediction Result:", retina_res)

    # 4. Test Foot Model with online sample foot image
    sample_foot_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Diabetic_foot_ulcer.jpg/640px-Diabetic_foot_ulcer.jpg"
    print(f"\nTesting Foot Model with URL: {sample_foot_url}")
    foot_res = predict_foot(sample_foot_url, model=registry.foot_model)
    print("Foot Prediction Result:", foot_res)

    # 5. Test Final Multi-Modal Aggregation
    final_res = predict_final(assessment_res, retina_res, foot_res)
    print("\nFINAL MULTI-MODAL PREDICTION RESULT:")
    print("Overall Risk:", final_res["overall_risk_percentage"], "%")
    print("Label:", final_res["prediction_label"])
    print("Risk Level:", final_res["risk_level"])
    print("Care Plan Recommendations:", final_res["care_plan"])
    print("==================================================")

if __name__ == "__main__":
    run_test()
