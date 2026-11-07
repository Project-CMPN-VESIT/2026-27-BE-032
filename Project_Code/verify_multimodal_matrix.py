import json
import sys
from pathlib import Path

project_root = Path(__file__).resolve().parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from backend.models.registry import ModelRegistry
from backend.services.prediction_service import (
    FEATURE_KEYS,
    _build_brfss_feature_vector,
    assess_diabetes,
    predict_final,
)


def base_payload() -> dict:
    return {
        "HighBP": 0,
        "HighChol": 0,
        "CholCheck": 1,
        "BMI": 22.5,
        "Smoker": 0,
        "Stroke": 0,
        "HeartDiseaseorAttack": 0,
        "PhysActivity": 1,
        "Fruits": 1,
        "Veggies": 1,
        "HvyAlcoholConsump": 0,
        "AnyHealthcare": 1,
        "NoDocbcCost": 0,
        "GenHlth": 1,
        "MentHlth": 0,
        "PhysHlth": 0,
        "DiffWalk": 0,
        "Sex": 1,
        "Age": 3,
        "Education": 5,
        "Income": 7,
    }


def abnormal_payload() -> dict:
    return {
        "HighBP": 1,
        "HighChol": 1,
        "CholCheck": 0,
        "BMI": 42,
        "Smoker": 1,
        "Stroke": 1,
        "HeartDiseaseorAttack": 1,
        "PhysActivity": 0,
        "Fruits": 0,
        "Veggies": 0,
        "HvyAlcoholConsump": 1,
        "AnyHealthcare": 0,
        "NoDocbcCost": 1,
        "GenHlth": 5,
        "MentHlth": 30,
        "PhysHlth": 30,
        "DiffWalk": 1,
        "Sex": 0,
        "Age": 12,
        "Education": 1,
        "Income": 1,
    }


registry = ModelRegistry()
registry.load_all()

normal_assessment = assess_diabetes(base_payload(), model=registry.assessment_model)
all_abnormal_assessment = assess_diabetes(abnormal_payload(), model=registry.assessment_model)
feature_vector = _build_brfss_feature_vector(abnormal_payload())[0]
print("=== ASSESSMENT FEATURE TRACE ===")
print("Exact 21-feature vector order:", FEATURE_KEYS)
print("Feature values:", [round(float(v), 6) for v in feature_vector.tolist()])
print("Assessment result for all-abnormal payload:")
print(json.dumps({
    "risk_percentage": all_abnormal_assessment["risk_percentage"],
    "target": all_abnormal_assessment["target"],
    "prediction": all_abnormal_assessment["prediction"],
    "risk_level": all_abnormal_assessment["risk_level"],
}, indent=2))

healthy_retina = {"prediction": "Healthy Fundus - No Retinopathy", "severity": "No Retinopathy", "risk_level": "healthy", "confidence": 90.0}
mild_retina = {"prediction": "Mild Non-Proliferative Retinopathy", "severity": "Mild Retinopathy", "risk_level": "prediabetic", "confidence": 92.5}
normal_foot = {"status": "NORMAL", "prediction": "NORMAL", "confidence": 92.0}
mild_foot = {"status": "MILD FINDING", "prediction": "MILD FINDING", "confidence": 88.5}
severe_foot = {"status": "SEVERE FINDING", "prediction": "SEVERE FINDING", "confidence": 93.0}

cases = [
    ("A. All normal", normal_assessment, healthy_retina, normal_foot),
    ("B. Eye only abnormal", normal_assessment, mild_retina, normal_foot),
    ("C. Foot only abnormal", normal_assessment, healthy_retina, mild_foot),
    ("D. Assessment only abnormal", all_abnormal_assessment, healthy_retina, normal_foot),
    ("E. Assessment + Eye abnormal", all_abnormal_assessment, mild_retina, normal_foot),
    ("F. Assessment + Foot abnormal", all_abnormal_assessment, healthy_retina, mild_foot),
    ("G. Eye + Foot abnormal", normal_assessment, mild_retina, mild_foot),
    ("H. All three abnormal", all_abnormal_assessment, mild_retina, severe_foot),
]

print("\n=== 8 CASE MULTIMODAL MATRIX VERIFICATION ===")
for label, assessment, retina, foot in cases:
    result = predict_final(assessment, retina, foot)
    print(f"{label}: {result['prediction_label']} / {result['overall_risk_percentage']}%")
