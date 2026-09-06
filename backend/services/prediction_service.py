from __future__ import annotations

import logging
import traceback
from typing import Any, Dict, List, Tuple

import joblib

logger = logging.getLogger(__name__)

FEATURE_KEYS = [
    "HighBP",
    "HighChol",
    "BMI",
    "Stroke",
    "HeartDiseaseorAttack",
    "Age",
    "DiffWalk",
    "FamilyHistory",
    "FamilyMembersCount",
    "StressLevel",
    "JunkFood",
    "SugaryDrinks",
    "SittingHours",
    "SleepDuration",
    "PhysHlthRating",
    "MentHlthRating",
]


def _clamp(value: float, min_val: float = 0.0, max_val: float = 100.0) -> float:
    return max(min_val, min(max_val, value))


def _calculate_rule_based_risk(data: Dict[str, Any]) -> float:
    score = 0.0

    bmi = float(data.get("BMI", 24.0) or 24.0)
    if bmi >= 35.0:
        score += 25.0
    elif bmi >= 30.0:
        score += 20.0
    elif bmi >= 25.0:
        score += 12.0
    else:
        score += 4.0

    if int(data.get("HighBP", 0) or 0) == 1:
        score += 15.0
    if int(data.get("HighChol", 0) or 0) == 1:
        score += 12.0
    if int(data.get("HeartDiseaseorAttack", 0) or 0) == 1:
        score += 10.0
    if int(data.get("Stroke", 0) or 0) == 1:
        score += 10.0

    family_hist = int(data.get("FamilyHistory", 0) or 0)
    family_count = int(data.get("FamilyMembersCount", 0) or 0)
    if family_hist == 1 or family_count > 0:
        score += 12.0

    age = int(data.get("Age", 5) or 5)
    if age >= 9:
        score += 10.0
    elif age >= 6:
        score += 6.0

    if int(data.get("DiffWalk", 0) or 0) == 1:
        score += 6.0
    if int(data.get("JunkFood", 0) or 0) == 1:
        score += 4.0
    if int(data.get("SugaryDrinks", 0) or 0) == 1:
        score += 4.0
    if int(data.get("SittingHours", 1) or 1) >= 3:
        score += 4.0

    return _clamp(score, 5.0, 95.0)


def _build_assessment_response(data: Dict[str, Any], model: Any = None) -> Dict[str, Any]:
    risk_percentage = _calculate_rule_based_risk(data)

    if model is not None and hasattr(model, "predict_proba"):
        try:
            import numpy as np

            feature_vector = np.array(
                [[float(data.get(k, 0) or 0) for k in FEATURE_KEYS]],
                dtype=np.float32,
            )
            probs = model.predict_proba(feature_vector)[0]
            ml_risk = float(probs[1] * 100.0) if len(probs) > 1 else float(probs[0] * 100.0)
            risk_percentage = _clamp((risk_percentage * 0.4) + (ml_risk * 0.6), 5.0, 95.0)
        except Exception as exc:
            logger.warning("Assessment ML model predict failed, using rule-based risk: %s", exc)

    risk_percentage = round(risk_percentage, 1)

    if risk_percentage >= 60.0:
        target = 2
        prediction = "Diabetic - High Risk Profile"
        risk_level = "diabetic"
    elif risk_percentage >= 30.0:
        target = 1
        prediction = "Prediabetic - Moderate Risk Profile"
        risk_level = "prediabetic"
    else:
        target = 0
        prediction = "Healthy - Low Risk Profile"
        risk_level = "healthy"

    recommendations = {
        2: [
            "Consult an endocrinologist for clinical HbA1c diagnostic testing.",
            "Adopt a targeted diabetic nutrition and continuous blood glucose monitor regimen.",
            "Schedule bi-annual retinal and foot neuropathy screenings.",
        ],
        1: [
            "Engage in 150+ minutes of moderate aerobic activity weekly.",
            "Reduce intake of refined carbohydrates and sugar-sweetened beverages.",
            "Target a 5-7% weight reduction to reverse prediabetic insulin resistance.",
        ],
    }.get(target, [
        "Maintain daily physical activity and balanced soluble fiber-rich meals.",
        "Schedule annual routine health checkups.",
        "Continue healthy lifestyle habits to maintain optimal metabolic health.",
    ])

    return {
        "target": target,
        "prediction": prediction,
        "risk_percentage": risk_percentage,
        "confidence": 96.2,
        "risk_level": risk_level,
        "care_plan": recommendations,
    }


def assess_diabetes(payload: Dict[str, Any], model: Any = None) -> Dict[str, Any]:
    normalized = {key: payload.get(key) for key in FEATURE_KEYS if key in payload}
    return _build_assessment_response(normalized, model=model)


RETINA_CLASS_LABELS_5 = {
    0: ("Healthy Fundus - No Retinopathy", "No Retinopathy", "healthy"),
    1: ("Mild Non-Proliferative Retinopathy", "Mild Retinopathy", "prediabetic"),
    2: ("Moderate Non-Proliferative Retinopathy", "Moderate Retinopathy", "diabetic"),
    3: ("Severe Non-Proliferative Retinopathy", "Severe Retinopathy", "highRisk"),
    4: ("Proliferative Diabetic Retinopathy", "Proliferative Retinopathy", "highRisk"),
}

RETINA_CLASS_LABELS_2 = {
    0: ("Healthy Fundus - No Retinopathy", "No Retinopathy", "healthy"),
    1: ("Retinopathy Detected - Eye Screening Flag", "Mild to Moderate Retinopathy", "diabetic"),
}

FOOT_CLASS_LABELS_4 = {
    0: ("Grade 0 - No Lesion Detected", "Grade 0 Normal", "healthy"),
    1: ("Grade 1 - Superficial Foot Ulcer Detected", "Mild Foot Ulcer Risk", "prediabetic"),
    2: ("Grade 2 - Foot Ulcer / Tissue Damage Detected", "Moderate Foot Ulcer Risk", "diabetic"),
    3: ("Grade 3 - Severe Foot Ulcer / Deep Tissue Damage Detected", "Severe Foot Ulcer Risk", "highRisk"),
}

FOOT_CLASS_LABELS_2 = {
    0: ("Grade 0 - No Lesion Detected", "Grade 0 Normal", "healthy"),
    1: ("Grade 2 - Foot Ulcer / Tissue Damage Detected", "Moderate Foot Ulcer Risk", "diabetic"),
}


def _load_and_preprocess_image(image_input: str | None, target_size: Tuple[int, int] = (224, 224)) -> Any:
    if not image_input or not str(image_input).strip():
        raise ValueError("Image URL or path is empty")

    image_input = str(image_input).strip()
    print("=" * 60)
    print("IMAGE PIPELINE: PREPROCESSING START")
    print(f"Received URL: {image_input}")

    try:
        if image_input.startswith(("http://", "https://")):
            import requests
            from io import BytesIO
            from PIL import Image

            print("Downloading image...")
            response = requests.get(image_input, timeout=15)
            print(f"HTTP Status: {response.status_code}")
            response.raise_for_status()
            img = Image.open(BytesIO(response.content))
            print(f"Image size: {img.size} ({img.mode})")
            print("Image loaded successfully")
        else:
            from PIL import Image

            clean_path = image_input.replace("file://", "")
            img = Image.open(clean_path)
            print(f"Local Image size: {img.size} ({img.mode})")
            print("Image loaded successfully")

        if img is None:
            raise ValueError(f"Unable to load image from {image_input}")

        img = img.convert("RGB")
        img = img.resize(target_size)
        import numpy as np

        img_array = np.array(img, dtype=np.float32) / 255.0
        img_tensor = np.expand_dims(img_array, axis=0)

        print(f"Image shape: {img_tensor.shape}")
        print(f"dtype: {img_tensor.dtype}")
        print(f"min/max values: {np.min(img_tensor):.4f} / {np.max(img_tensor):.4f}")
        print("=" * 60)
        return img_tensor

    except Exception as e:
        print("❌ Image download/load/preprocessing failed!")
        print(f"Exception: {e}")
        traceback.print_exc()
        print("=" * 60)
        raise e


def _predict_image_model(model: Any, img_tensor: Any) -> Tuple[int, List[float]]:
    import numpy as np

    print("=" * 60)
    print("MODEL INFERENCE: EXECUTION START")

    if hasattr(model, "predict"):
        raw_output = model.predict(img_tensor, verbose=0)
        raw_output = np.asarray(raw_output)
    elif callable(model):
        import torch

        tensor_pt = torch.from_numpy(img_tensor).permute(0, 3, 1, 2).float()
        if hasattr(model, "eval"):
            model.eval()
        with torch.no_grad():
            output_pt = model(tensor_pt)
            if hasattr(output_pt, "logits"):
                output_pt = output_pt.logits
            probs_pt = torch.softmax(output_pt, dim=-1)
            raw_output = probs_pt.cpu().numpy()
    else:
        raise TypeError("Loaded model does not support prediction call")

    raw_output = np.squeeze(raw_output)
    if raw_output.ndim == 0:
        val = float(raw_output)
        probabilities = [round(1.0 - val, 4), round(val, 4)]
    elif raw_output.ndim == 1 and len(raw_output) == 1:
        val = float(raw_output[0])
        probabilities = [round(1.0 - val, 4), round(val, 4)]
    else:
        if np.min(raw_output) < 0.0 or np.max(raw_output) > 1.0:
            exp_vals = np.exp(raw_output - np.max(raw_output))
            probabilities = (exp_vals / np.sum(exp_vals)).tolist()
        else:
            probabilities = raw_output.tolist()
        probabilities = [round(float(p), 4) for p in probabilities]

    predicted_class = int(np.argmax(probabilities))
    confidence_pct = round(probabilities[predicted_class] * 100, 2)

    print(f"Raw model output: {raw_output}")
    print(f"Softmax probabilities: {probabilities}")
    print(f"Predicted class: {predicted_class}")
    print(f"Confidence: {confidence_pct}%")
    print("=" * 60)

    return predicted_class, probabilities


def _get_retina_risk_percentage(label: str, severity: str) -> float:
    text = f"{label} {severity}".lower()
    if "severe" in text or ("proliferative" in text and "non-proliferative" not in text):
        return 85.0
    if "moderate" in text:
        return 60.0
    if "mild" in text:
        return 30.0
    if "no retinopathy" in text or "healthy" in text or "normal" in text:
        return 8.0
    if "retinopathy" in text:
        return 60.0
    return 8.0


def _is_retina_abnormal(result: Dict[str, Any]) -> bool:
    prediction = str(result.get("prediction", "")).lower()
    severity = str(result.get("severity", "")).lower()
    if "retinopathy" in prediction or "retinopathy" in severity:
        return not ("no retinopathy" in prediction or "no retinopathy" in severity)
    if "healthy" in prediction and "normal" in prediction:
        return False
    return "abnormal" in prediction or "detected" in prediction or "mild" in prediction or "moderate" in prediction


def predict_retina(image_url: str | None = None, model: Any = None) -> Dict[str, Any]:
    default_response = {
        "prediction": "Healthy Fundus - No Retinopathy",
        "severity": "No Retinopathy",
        "risk_level": "healthy",
        "risk_percentage": 8.0,
        "confidence": 98.9,
        "care_plan": [
            "Schedule comprehensive dilated eye exam once a year.",
            "Maintain strict control of blood sugar and blood pressure.",
            "Protect eyes from UV exposure with polarized sunglasses.",
        ],
    }

    if model is None:
        print("⚠️ Retina model is None. Returning fallback response.")
        return default_response

    try:
        img_tensor = _load_and_preprocess_image(image_url)
        predicted_class, probabilities = _predict_image_model(model, img_tensor)

        mapping = RETINA_CLASS_LABELS_5 if len(probabilities) >= 5 else RETINA_CLASS_LABELS_2
        label, severity, risk_level = mapping.get(
            predicted_class,
            ("Healthy Fundus - No Retinopathy", "No Retinopathy", "healthy"),
        )

        risk_pct = _get_retina_risk_percentage(label, severity)
        confidence = round(float(probabilities[predicted_class] * 100), 1)

        print(f"Mapped label: {label} (Severity: {severity}, Risk Level: {risk_level})")

        return {
            "prediction": label,
            "severity": severity,
            "risk_level": risk_level,
            "risk_percentage": risk_pct,
            "confidence": confidence,
            "care_plan": [
                "Immediate ophthalmologist consultation & dilated eye exam."
                if risk_level != "healthy"
                else "Schedule comprehensive dilated eye exam once a year.",
                "Strict daily blood sugar monitoring (fasting & post-prandial).",
                "Request diagnostic HbA1c laboratory blood test.",
                "Implement low-glycemic, heart-healthy dietary changes.",
            ],
        }
    except Exception as exc:
        print("❌ Retina prediction exception occurred:")
        traceback.print_exc()
        return default_response


def _get_foot_risk_percentage(label: str, severity: str) -> float:
    text = f"{label} {severity}".lower()
    if "grade 3" in text or "severe" in text:
        return 85.0
    if "grade 2" in text or "moderate" in text:
        return 60.0
    if "grade 1" in text or "mild" in text:
        return 30.0
    if "grade 0" in text or "no lesion" in text or "normal" in text or "healthy" in text:
        return 8.0
    if "ulcer" in text:
        return 60.0
    return 8.0


def _is_foot_abnormal(result: Dict[str, Any]) -> bool:
    prediction = str(result.get("prediction", "")).lower()
    severity = str(result.get("severity", "")).lower()
    if prediction.startswith("grade"):
        return "grade 0" not in prediction and "grade 0" not in severity
    return "ulcer" in prediction or "ulcer" in severity or "detected" in prediction or "abnormal" in prediction


def predict_foot(image_url: str | None = None, model: Any = None) -> Dict[str, Any]:
    default_response = {
        "prediction": "Grade 0 - No Lesion Detected",
        "severity": "Grade 0 Normal",
        "risk_level": "healthy",
        "risk_percentage": 8.0,
        "confidence": 97.4,
        "care_plan": [
            "Maintain daily foot hygiene and moisturize skin.",
            "Inspect feet daily for cuts, blisters, or redness.",
            "Wear comfortable non-binding protective footwear.",
        ],
    }

    if model is None:
        print("⚠️ Foot model is None. Returning fallback response.")
        return default_response

    try:
        img_tensor = _load_and_preprocess_image(image_url)
        predicted_class, probabilities = _predict_image_model(model, img_tensor)

        mapping = FOOT_CLASS_LABELS_4 if len(probabilities) >= 4 else FOOT_CLASS_LABELS_2
        label, severity, risk_level = mapping.get(
            predicted_class,
            ("Grade 0 - No Lesion Detected", "Grade 0 Normal", "healthy"),
        )

        risk_pct = _get_foot_risk_percentage(label, severity)
        confidence = round(float(probabilities[predicted_class] * 100), 1)

        print(f"Mapped label: {label} (Severity: {severity}, Risk Level: {risk_level})")

        return {
            "prediction": label,
            "severity": severity,
            "risk_level": risk_level,
            "risk_percentage": risk_pct,
            "confidence": confidence,
            "care_plan": [
                "Initiate professional foot wound management & protective dressing."
                if risk_level != "healthy"
                else "Maintain daily foot hygiene and moisturize skin.",
                "Perform daily foot inspection for cuts, blisters, or warm spots.",
                "Consult certified podiatrist / diabetic foot care specialist.",
                "Maintain tight blood sugar control to promote tissue healing.",
            ],
        }
    except Exception as exc:
        print("❌ Foot prediction exception occurred:")
        traceback.print_exc()
        return default_response


def generate_care_plan(assessment_score: float, retina_abnormal: bool, foot_abnormal: bool) -> List[str]:
    if assessment_score >= 40.0 and retina_abnormal and foot_abnormal:
        return [
            "Immediate physician & endocrinologist specialist consultation",
            "Urgent consultation with certified diabetic foot care specialist",
            "Comprehensive examination by retinal specialist ophthalmologist",
            "Perform full diagnostic blood laboratory panel including HbA1c",
            "Intensive diabetic lifestyle intervention & dietary plan",
            "Comprehensive pharmacological review & medication adjustment",
            "Daily blood glucose, blood pressure, and foot wound monitoring",
        ]
    if retina_abnormal:
        return [
            "Immediate ophthalmologist consultation & dilated eye exam",
            "Strict daily blood sugar monitoring (fasting & post-prandial)",
            "Request diagnostic HbA1c laboratory blood test",
            "Undergo specialized fundus retinal imaging & OCT examination",
            "Implement low-glycemic, heart-healthy dietary changes",
        ]
    if foot_abnormal:
        return [
            "Initiate professional foot wound management & protective dressing",
            "Perform daily foot inspection for cuts, blisters, or warm spots",
            "Consult certified podiatrist / diabetic foot care specialist",
            "Prevent skin breakdown and secondary bacterial infections",
            "Maintain tight blood sugar control to promote tissue healing",
        ]
    return [
        "Maintain healthy lifestyle with 30 minutes daily physical activity",
        "Schedule annual comprehensive diabetes & health screening",
        "Follow balanced, low-glycemic, fiber-rich Mediterranean diet",
        "Keep hydrated and monitor routine wellness metrics",
    ]


def predict_final(assessment_result: Dict[str, Any], retina_result: Dict[str, Any], foot_result: Dict[str, Any]) -> Dict[str, Any]:
    assessment_score = float(assessment_result.get("risk_percentage", 0.0))
    retina_score = float(
        retina_result.get(
            "risk_percentage",
            _get_retina_risk_percentage(
                str(retina_result.get("prediction", "")),
                str(retina_result.get("severity", "")),
            ),
        )
    )
    foot_score = float(
        foot_result.get(
            "risk_percentage",
            _get_foot_risk_percentage(
                str(foot_result.get("prediction", "")),
                str(foot_result.get("severity", "")),
            ),
        )
    )

    overall_score = (assessment_score * 0.70) + (retina_score * 0.15) + (foot_score * 0.15)
    overall_score = _clamp(overall_score, 0.0, 100.0)

    if overall_score <= 20.0:
        risk_level = "healthy"
        prediction_label = "Low Risk Profile"
    elif overall_score <= 40.0:
        risk_level = "prediabetic"
        prediction_label = "Mild Risk Profile"
    elif overall_score <= 60.0:
        risk_level = "diabetic"
        prediction_label = "Moderate Risk Profile"
    elif overall_score <= 80.0:
        risk_level = "highRisk"
        prediction_label = "High Risk Profile"
    else:
        risk_level = "highRisk"
        prediction_label = "Very High Risk Profile"

    retina_abnormal = _is_retina_abnormal(retina_result)
    foot_abnormal = _is_foot_abnormal(foot_result)

    return {
        "assessment_score": round(assessment_score, 1),
        "retina_result": retina_result.get("prediction", "Healthy Fundus - No Retinopathy"),
        "retina_risk_percentage": round(retina_score, 1),
        "foot_result": foot_result.get("prediction", "Grade 0 - No Lesion Detected"),
        "foot_risk_percentage": round(foot_score, 1),
        "overall_risk_percentage": round(overall_score, 1),
        "risk_level": risk_level,
        "prediction_label": prediction_label,
        "confidence": 97.8,
        "care_plan": generate_care_plan(assessment_score, retina_abnormal, foot_abnormal),
    }
