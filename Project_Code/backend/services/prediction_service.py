from __future__ import annotations

from datetime import datetime
import logging
import math
import os
import traceback
from typing import Any, Dict, List, Tuple
from PIL import Image

import joblib

logger = logging.getLogger(__name__)

FEATURE_KEYS = [
    "HighBP",
    "HighChol",
    "CholCheck",
    "BMI",
    "Smoker",
    "Stroke",
    "HeartDiseaseorAttack",
    "PhysActivity",
    "Fruits",
    "Veggies",
    "HvyAlcoholConsump",
    "AnyHealthcare",
    "NoDocbcCost",
    "GenHlth",
    "MentHlth",
    "PhysHlth",
    "DiffWalk",
    "Sex",
    "Age",
    "Education",
    "Income",
]

DISCRETE_FEATURE_KEYS = {
    "HighBP",
    "HighChol",
    "CholCheck",
    "Smoker",
    "Stroke",
    "HeartDiseaseorAttack",
    "PhysActivity",
    "Fruits",
    "Veggies",
    "HvyAlcoholConsump",
    "AnyHealthcare",
    "NoDocbcCost",
    "GenHlth",
    "MentHlth",
    "PhysHlth",
    "DiffWalk",
    "Sex",
    "Age",
    "Education",
    "Income",
}


REQUIRED_ASSESSMENT_KEYS = [
    "HighBP",
    "HighChol",
    "CholCheck",
    "BMI",
    "Smoker",
    "Stroke",
    "HeartDiseaseorAttack",
    "Age",
    "Sex",
    "DiffWalk",
]


BRFSS_MEANS = [
    0.429, 0.424, 0.963, 28.382, 0.443, 0.041, 0.094,
    0.757, 0.634, 0.811, 0.056, 0.951, 0.084,
    2.511, 3.185, 4.242, 0.168, 0.440, 8.032, 5.050, 6.054
]

BRFSS_STDS = [
    0.495, 0.494, 0.190, 6.609, 0.497, 0.198, 0.292,
    0.429, 0.482, 0.391, 0.230, 0.216, 0.278,
    1.068, 7.413, 8.718, 0.374, 0.496, 3.054, 0.986, 2.071
]


def _build_brfss_feature_vector(data: Dict[str, Any]):
    import numpy as np

    positive_frequency_thresholds = {
        "PhysActivity": 1,
        "Fruits": 2,
        "Veggies": 2,
    }
    raw_values = []
    for key in FEATURE_KEYS:
        value = data.get(key)
        if value is None:
            raw_values.append(np.nan)
            continue
        numeric_value = float(value)
        if key in positive_frequency_thresholds:
            numeric_value = float(
                numeric_value >= positive_frequency_thresholds[key]
            )
        raw_values.append(numeric_value)

    raw = np.asarray(raw_values, dtype=np.float32)

    means = np.array(BRFSS_MEANS, dtype=np.float32)
    stds = np.array(BRFSS_STDS, dtype=np.float32)
    scaled = (raw - means) / stds
    return np.expand_dims(scaled, axis=0)


def _build_assessment_response(data: Dict[str, Any], model: Any = None) -> Dict[str, Any]:
    import numpy as np

    if model is None or not hasattr(model, "predict_proba"):
        raise RuntimeError("The XGBoost assessment model is unavailable.")

    classes = getattr(model, "classes_", None)
    if classes is None:
        raise RuntimeError("The assessment model does not expose its trained classes.")
    class_indexes = {int(value): index for index, value in enumerate(classes)}
    if set(class_indexes) != {0, 1}:
        raise RuntimeError(
            "The loaded assessment model is not the expected binary BRFSS model."
        )

    feature_vector = _build_brfss_feature_vector(data)
    if feature_vector.shape[1] != len(FEATURE_KEYS):
        raise RuntimeError("The assessment feature vector does not match the model.")
    probabilities = np.asarray(model.predict_proba(feature_vector), dtype=float)
    if (
        probabilities.shape != (1, len(classes))
        or not np.isfinite(probabilities).all()
        or np.any(probabilities < 0.0)
        or np.any(probabilities > 1.0)
        or not np.isclose(probabilities.sum(), 1.0, atol=1e-5)
    ):
        raise RuntimeError("The assessment model returned invalid probabilities.")

    normal_probability = float(probabilities[0, class_indexes[0]])
    combined_probability = float(probabilities[0, class_indexes[1]])
    target = int(classes[int(np.argmax(probabilities[0]))])
    risk_percentage = round(combined_probability * 100.0, 2)

    if target == 1:
        prediction = "Combined prediabetes/diabetes indicator predicted"
        risk_level = "borderline"
        explanation = (
            "The binary model's positive class combines prediabetes and diabetes. "
            "This is a screening output, not a diagnosis."
        )
        recommendations = [
            "Discuss this screening result with a qualified healthcare professional.",
            "Clinical testing is needed to determine whether diabetes or prediabetes is present.",
        ]
    else:
        prediction = "No combined prediabetes/diabetes indicator predicted"
        risk_level = "healthy"
        explanation = (
            "The binary model predicted its no-indicator class. This screening "
            "output does not rule out diabetes or replace clinical testing."
        )
        recommendations = [
            "Continue routine health checks and discuss concerns with a clinician.",
        ]

    return {
        "target": target,
        "prediction": prediction,
        "risk_percentage": risk_percentage,
        "class_probabilities": {
            "normal": round(normal_probability * 100.0, 2),
            "borderline": None,
            "diabetes": None,
            "combined_prediabetes_diabetes": risk_percentage,
        },
        "probability_source": "raw_xgboost_predict_proba",
        "probability_calibration": (
            "Not independently calibrated; the model artifact has no saved "
            "training scaler, so inference uses the bundled rounded BRFSS "
            "scaling statistics."
        ),
        "explanation": explanation,
        "risk_level": risk_level,
        "care_plan": recommendations,
    }


def assess_diabetes(payload: Dict[str, Any], model: Any = None) -> Dict[str, Any]:
    missing = [
        key
        for key in REQUIRED_ASSESSMENT_KEYS
        if key not in payload or payload[key] is None
    ]
    if missing:
        raise ValueError(
            "Missing required assessment fields: " + ", ".join(missing)
        )

    normalized: Dict[str, Any] = {}
    for key in FEATURE_KEYS:
        if key not in payload or payload[key] is None:
            continue
        value = payload[key]
        if (
            isinstance(value, bool)
            or not isinstance(value, (int, float))
            or not math.isfinite(float(value))
        ):
            raise ValueError(f"Assessment field {key} must be a finite number.")
        if key in DISCRETE_FEATURE_KEYS and not float(value).is_integer():
            raise ValueError(f"Assessment field {key} must be a whole-number category.")
        normalized[key] = value
    expected_ranges = {
        "HighBP": (0, 1),
        "HighChol": (0, 1),
        "CholCheck": (0, 1),
        "BMI": (1, 100),
        "Smoker": (0, 1),
        "Stroke": (0, 1),
        "HeartDiseaseorAttack": (0, 1),
        "Age": (1, 13),
        "Sex": (0, 1),
        "PhysActivity": (0, 3),
        "Fruits": (0, 2),
        "Veggies": (0, 2),
        "HvyAlcoholConsump": (0, 1),
        "AnyHealthcare": (0, 1),
        "NoDocbcCost": (0, 1),
        "GenHlth": (1, 5),
        "MentHlth": (0, 30),
        "PhysHlth": (0, 30),
        "DiffWalk": (0, 1),
        "Education": (1, 6),
        "Income": (1, 8),
    }
    for key, (minimum, maximum) in expected_ranges.items():
        if key not in normalized:
            continue
        value = float(normalized[key])
        if not minimum <= value <= maximum:
            raise ValueError(
                f"Assessment field {key} must be between {minimum} and {maximum}."
            )
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

FOOT_TRAINING_CLASS_NAMES = {
    0: "Original Images",
    1: "Patches",
    2: "TestSet",
    3: "Transfer-Learning images",
}


def _load_and_preprocess_image(
    image_input: Any,
    target_size: Tuple[int, int] = (224, 224),
    is_torch: bool = False,
    is_foot: bool = False,
) -> Any:
    if image_input is None:
        raise ValueError("Image input is None")

    from io import BytesIO
    from PIL import Image
    import numpy as np

    print("=" * 60)
    print("IMAGE PIPELINE: PREPROCESSING START")

    try:
        if isinstance(image_input, bytes):
            print("Loading image from raw bytes (multipart/form-data upload)...")
            img = Image.open(BytesIO(image_input))
            print(f"Uploaded Image size: {img.size} ({img.mode})")
        elif isinstance(image_input, str):
            image_input_str = image_input.strip()
            print(f"Received String Input: {image_input_str}")
            if image_input_str.startswith(("http://", "https://")):
                import requests
                print("Downloading image from HTTP URL...")
                response = requests.get(image_input_str, timeout=15)
                print(f"HTTP Status: {response.status_code}")
                response.raise_for_status()
                img = Image.open(BytesIO(response.content))
                print(f"Downloaded Image size: {img.size} ({img.mode})")
            else:
                clean_path = image_input_str.replace("file://", "")
                img = Image.open(clean_path)
                print(f"Local Image size: {img.size} ({img.mode})")
        else:
            raise TypeError(f"Unsupported image input type: {type(image_input)}")

        img_orig = img.convert("RGB")
        print(f"[IMAGE] 1. Original Uploaded Image Dimensions: {img_orig.size}")

        if is_foot:
            print("[PREPROCESS] Matching ImageDataGenerator: RGB, 224x224, nearest resize, rescale 1/255.")
            img_final = img_orig.resize(
                target_size,
                resample=Image.Resampling.NEAREST,
            )
        else:
            img_final = img_orig.resize(target_size)

        img_array = np.array(img_final, dtype=np.float32) / 255.0
        img_tensor = np.expand_dims(img_array, axis=0)

        print(f"Image tensor shape: {img_tensor.shape}, min/max: {np.min(img_tensor):.4f} / {np.max(img_tensor):.4f}")
        print("=" * 60)
        return img_tensor

    except Exception as e:
        print(f"[ERROR] Image download/load/preprocessing failed: {e}")
        traceback.print_exc()
        print("=" * 60)
        raise e


def _predict_image_model(model: Any, img_tensor: Any) -> Tuple[int, List[float]]:
    import numpy as np

    print("=" * 60)
    print("MODEL INFERENCE: EXECUTION START")

    if hasattr(model, "predict"):
        # Model was trained with ImageDataGenerator(rescale=1./255) in capstone_project.py
        # Normalized input tensor in [0.0, 1.0] is passed directly.
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
    print(f"Raw model output (logits/probs): {raw_output}")

    if raw_output.ndim == 0 or (raw_output.ndim == 1 and len(raw_output) == 1):
        val = float(raw_output.item() if hasattr(raw_output, "item") else raw_output[0])
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

    print(f"Softmax probabilities : {probabilities}")
    print(f"Predicted class index : {predicted_class}")
    print(f"Confidence            : {confidence_pct}%")
    print("=" * 60)

    return predicted_class, probabilities


def _is_retina_abnormal(result: Dict[str, Any]) -> bool:
    prediction = str(result.get("prediction", "")).lower()
    severity = str(result.get("severity", "")).lower()
    if "retinopathy" in prediction or "retinopathy" in severity:
        return not ("no retinopathy" in prediction or "no retinopathy" in severity)
    if "healthy" in prediction and "normal" in prediction:
        return False
    return "abnormal" in prediction or "detected" in prediction or "mild" in prediction or "moderate" in prediction


def predict_retina(image_url: str | None = None, model: Any = None) -> Dict[str, Any]:
    if model is None:
        raise RuntimeError("Retina model is unavailable; no result was produced.")

    try:
        img_tensor = _load_and_preprocess_image(image_url, is_torch=True)
        predicted_class, probabilities = _predict_image_model(model, img_tensor)

        mapping = RETINA_CLASS_LABELS_5 if len(probabilities) >= 5 else RETINA_CLASS_LABELS_2
        label, severity, risk_level = mapping.get(
            predicted_class,
            ("Healthy Fundus - No Retinopathy", "No Retinopathy", "healthy"),
        )

        confidence = round(float(probabilities[predicted_class] * 100), 1)

        print(f"Mapped label: {label} (Severity: {severity}, Risk Level: {risk_level})")

        return {
            "prediction": label,
            "severity": severity,
            "risk_level": risk_level,
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
        logger.exception("Retina prediction failed.")
        raise RuntimeError("Retina prediction failed; no result was produced.") from exc


def _is_foot_abnormal(result: Dict[str, Any]) -> bool:
    status = str(result.get("status", "")).lower()
    prediction = str(result.get("prediction", "")).lower()
    severity = str(result.get("severity", "")).lower()
    return (
        status == "ulcer suspected"
        or status == "severe finding"
        or prediction == "ulcer suspected"
        or prediction == "severe finding"
        or severity == "ulcer suspected"
        or severity == "severe finding"
    )


def predict_foot(image_url: str | bytes | None = None) -> Dict[str, Any]:
    if image_url is None:
        raise ValueError("A foot image is required for prediction")

    from backend.services.opencv_foot_service import analyze_foot_image

    return analyze_foot_image(image_url)


def generate_care_plan(
    assessment_positive: bool, retina_abnormal: bool, foot_abnormal: bool
) -> List[str]:
    if assessment_positive and retina_abnormal and foot_abnormal:
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
    def valid_percentage(value: Any) -> float | None:
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            return None
        score = float(value)
        return score if math.isfinite(score) and 0.0 <= score <= 100.0 else None

    assessment_score = valid_percentage(assessment_result.get("risk_percentage"))
    retina_prediction = retina_result.get("prediction")
    foot_prediction = foot_result.get("status") or foot_result.get("prediction")
    if assessment_score is None:
        raise ValueError("A valid diabetes assessment score is required.")
    if not isinstance(retina_prediction, str) or not retina_prediction.strip():
        raise ValueError("A completed retina result is required.")
    if not isinstance(foot_prediction, str) or not foot_prediction.strip():
        raise ValueError("A completed foot result is required.")

    target = assessment_result.get("target")
    if target in (0, 1):
        assessment_positive = target == 1
        assessment_inconclusive = False
    else:
        assessment_label = str(assessment_result.get("prediction", "")).lower()
        assessment_risk_level = str(
            assessment_result.get("risk_level", "")
        ).lower()
        if assessment_risk_level == "healthy" or assessment_label.strip() in {
            "normal",
            "healthy",
        } or "no combined" in assessment_label:
            assessment_positive = False
            assessment_inconclusive = False
        elif assessment_risk_level in {"borderline", "prediabetic", "diabetic"} or (
            "combined prediabetes/diabetes" in assessment_label
        ):
            assessment_positive = True
            assessment_inconclusive = False
        else:
            assessment_positive = False
            assessment_inconclusive = True

    retina_score = None

    foot_label = " ".join(
        str(foot_result.get(key, "")).lower()
        for key in ("status", "prediction", "risk_level")
    )
    foot_ulcer_suspected = (
        "ulcer suspected" in foot_label or "severe finding" in foot_label
    )
    foot_score = None
    foot_inconclusive = "inconclusive" in foot_label

    retina_abnormal = _is_retina_abnormal(retina_result)
    if (
        assessment_positive
        or assessment_inconclusive
        or retina_abnormal
        or foot_ulcer_suspected
    ):
        risk_level = "borderline"
        prediction_label = "Borderline / Further Assessment"
    else:
        risk_level = "healthy"
        prediction_label = "Normal"

    if foot_inconclusive:
        logger.info("Foot result is inconclusive; it is excluded from overall status.")

    foot_abnormal = _is_foot_abnormal(foot_result)
    class_probabilities = assessment_result.get("class_probabilities")
    if not isinstance(class_probabilities, dict):
        class_probabilities = None
    else:
        class_probabilities = {
            key: valid_percentage(value)
            for key, value in class_probabilities.items()
            if key in {
                "normal",
                "borderline",
                "diabetes",
                "combined_prediabetes_diabetes",
            }
        }

    return {
        "assessment_score": round(assessment_score, 2),
        "assessment_class_probabilities": class_probabilities,
        "assessment_explanation": assessment_result.get("explanation"),
        "assessment_probability_calibration": assessment_result.get(
            "probability_calibration"
        ),
        "retina_result": retina_prediction,
        "retina_risk_percentage": round(retina_score, 1)
        if retina_score is not None
        else None,
        "retina_confidence": valid_percentage(retina_result.get("confidence")),
        "foot_result": foot_prediction,
        "foot_risk_percentage": round(foot_score, 1)
        if foot_score is not None
        else None,
        "foot_confidence": valid_percentage(foot_result.get("confidence")),
        "overall_risk_percentage": None,
        "risk_level": risk_level,
        "prediction_label": prediction_label,
        "care_plan": generate_care_plan(
            assessment_positive, retina_abnormal, foot_abnormal
        ),
    }
