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

    # Map general health from PhysHlthRating if GenHlth not directly provided
    # In Flutter questionnaire: 1=Excellent, 2=Good, 3=Fair, 4=Poor
    # In BRFSS: 1=Excellent, 2=Very Good, 3=Good, 4=Fair, 5=Poor
    phys_rating = data.get("PhysHlthRating")
    gen_hlth = data.get("GenHlth")
    phys_hlth = data.get("PhysHlth")
    ment_hlth = data.get("MentHlth")

    if gen_hlth is None and phys_rating is not None:
        if phys_rating == 1:
            gen_hlth = 1.0
        elif phys_rating == 2:
            gen_hlth = 2.0
        elif phys_rating == 3:
            gen_hlth = 4.0
        elif phys_rating == 4:
            gen_hlth = 5.0

    if phys_hlth is None and phys_rating is not None:
        if phys_rating == 1:
            phys_hlth = 0.0
        elif phys_rating == 2:
            phys_hlth = 2.0
        elif phys_rating == 3:
            phys_hlth = 14.0
        elif phys_rating == 4:
            phys_hlth = 28.0

    ment_rating = data.get("MentHlthRating")
    if ment_hlth is None and ment_rating is not None:
        if ment_rating == 1:
            ment_hlth = 0.0
        elif ment_rating == 2:
            ment_hlth = 2.0
        elif ment_rating == 3:
            ment_hlth = 12.0
        elif ment_rating == 4:
            ment_hlth = 25.0

    high_chol = data.get("HighChol")
    chol_check = data.get("CholCheck")
    if chol_check is None and high_chol is not None and float(high_chol) == 1.0:
        chol_check = 1.0

    mapped_values = {
        "GenHlth": gen_hlth,
        "PhysHlth": phys_hlth,
        "MentHlth": ment_hlth,
        "CholCheck": chol_check,
    }

    positive_frequency_thresholds = {
        "PhysActivity": 1,
        "Fruits": 2,
        "Veggies": 2,
    }

    raw_values = []
    for key in FEATURE_KEYS:
        val = data.get(key)
        if val is None:
            val = mapped_values.get(key)
        if val is None:
            raw_values.append(np.nan)
            continue
        num = float(val)
        if key in positive_frequency_thresholds:
            num = float(num >= positive_frequency_thresholds[key])
        raw_values.append(num)

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


def _is_assessment_abnormal(result: Dict[str, Any]) -> bool:
    risk_pct = result.get("risk_percentage")
    if isinstance(risk_pct, (int, float)) and math.isfinite(float(risk_pct)):
        return float(risk_pct) >= 35.0

    target = result.get("target")
    if target in (0, 1):
        return target == 1

    risk_level = str(result.get("risk_level", "")).lower()
    if risk_level in {"borderline", "prediabetic", "diabetic", "highrisk"}:
        return True
    prediction = str(result.get("prediction", "")).lower()
    if "combined prediabetes/diabetes" in prediction or "indicator predicted" in prediction:
        return True
    return False


def _is_retina_abnormal(result: Dict[str, Any]) -> bool:
    prediction = str(result.get("prediction", "")).lower()
    severity = str(result.get("severity", "")).lower()
    risk_level = str(result.get("risk_level", "")).lower()
    if risk_level in {"prediabetic", "diabetic", "highrisk", "inconclusive"}:
        return True
    if "inconclusive" in prediction or "inconclusive" in severity:
        return True
    if "no retinopathy" in prediction or "no retinopathy" in severity:
        return False
    if "healthy" in prediction and "normal" in prediction:
        return False
    return (
        "retinopathy" in prediction
        or "retinopathy" in severity
        or "abnormal" in prediction
        or "detected" in prediction
    )


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


def _normalize_foot_status(value: Any) -> str:
    text = str(value or "").strip().upper()
    if not text:
        return ""
    aliases = {
        "NO LESION DETECTED": "NORMAL",
        "HEALTHY FOOT": "NORMAL",
        "HEALTHY FOOT SKIN": "NORMAL",
        "NO LOCALIZED WOUND": "NORMAL",
        "NORMAL SKIN": "NORMAL",
        "MILD FINDING DETECTED": "MILD FINDING",
        "MILD FOOT ULCER": "MILD FINDING",
        "FOOT ULCER DETECTED": "SEVERE FINDING",
        "SEVERE FOOT ULCER DETECTED": "SEVERE FINDING",
        "SEVERE FINDING": "SEVERE FINDING",
        "MILD FINDING": "MILD FINDING",
        "ULCER SUSPECTED": "SEVERE FINDING",
        "INCONCLUSIVE": "INCONCLUSIVE",
    }
    return aliases.get(text, text)


def _is_foot_abnormal(result: Dict[str, Any]) -> bool:
    status = _normalize_foot_status(result.get("status"))
    prediction = _normalize_foot_status(result.get("prediction"))
    severity = _normalize_foot_status(result.get("severity"))
    finding = str(result.get("finding", "")).upper()

    if status == "INCONCLUSIVE" or prediction == "INCONCLUSIVE" or severity == "INCONCLUSIVE":
        return True
    if status in {"NORMAL"}:
        return False
    if prediction in {"NORMAL"}:
        return False
    if severity in {"NORMAL"}:
        return False
    if "NO LESION" in finding or "NO LOCALIZED WOUND" in finding or "HEALTHY FOOT SKIN" in finding:
        return False

    if status in {"MILD FINDING", "SEVERE FINDING"}:
        return True
    if prediction in {"MILD FINDING", "SEVERE FINDING"}:
        return True
    if severity in {"MILD FINDING", "SEVERE FINDING"}:
        return True

    text = f"{status} {prediction} {severity} {finding}".lower()
    has_ulcer_marker = "ulcer" in text or "lesion" in text or "tissue damage" in text
    return has_ulcer_marker and not ("synthetic" in text or "ambiguous" in text or "insufficient" in text)


def predict_foot(image_url: str | bytes | None = None, model: Any = None) -> Dict[str, Any]:
    if image_url is None:
        raise ValueError("A foot image is required for prediction")

    from backend.services.opencv_foot_service import analyze_foot_image

    # 1. OpenCV photographic quality, metrics and bounding box regions
    cv_result = analyze_foot_image(image_url)
    if cv_result.get("status") == "INCONCLUSIVE":
        return cv_result

    # 2. ResNet50 Deep Learning Prediction if model is loaded
    if model is not None:
        try:
            import io
            import numpy as np
            from PIL import Image

            if isinstance(image_url, bytes):
                img = Image.open(io.BytesIO(image_url))
            elif isinstance(image_url, str):
                clean_path = image_url.replace("file://", "").strip()
                img = Image.open(clean_path)
            elif isinstance(image_url, Image.Image):
                img = image_url
            else:
                img = None

            if img is not None:
                img_rgb = img.convert("RGB").resize((224, 224), resample=Image.Resampling.NEAREST)
                arr = np.array(img_rgb, dtype=np.float32) / 255.0
                preds = model.predict(np.expand_dims(arr, axis=0), verbose=0)[0]
                p0, p1, p2, p3 = [float(x) for x in preds]
                argmax = int(np.argmax(preds))

                # Class 1 = Normal Skin (Patches)
                # Class 0, 3 = Severe Ulcer Wounds (Original Images & Transfer-Learning)
                # Class 2 = TestSet Ulcers
                if argmax == 1 and p1 >= 0.45:
                    status = "NORMAL"
                    confidence = round(p1 * 100, 1)
                    finding = "No localized wound-like lesion or tissue breakdown identified."
                    description = "ResNet-50 deep learning model identified healthy foot skin tissue with no active ulceration."
                    reason = "Normal skin color distribution and absence of ulcerated lesion boundaries."
                elif argmax in (0, 3) or (p0 + p3) >= 0.50:
                    status = "SEVERE FINDING"
                    confidence = round(max(p0, p3) * 100, 1)
                    finding = f"Deep learning analysis identified active diabetic foot ulceration and significant tissue damage ({confidence}% confidence)."
                    description = "Trained DFU ResNet50 model found signs consistent with severe diabetic foot ulceration; seek prompt clinical evaluation."
                    reason = "Model detected severe localized ulcer wound boundary, tissue discoloration, and structural skin disruption."
                else:
                    status = "MILD FINDING"
                    confidence = round(max(p0, p2, p3) * 100, 1)
                    finding = f"Deep learning screening detected early localized tissue change / mild lesion ({confidence}% confidence)."
                    description = "Screening found a localized region with wound-like visual features; clinical review is recommended."
                    reason = "Mild superficial lesion or localized discoloration detected without extensive deep ulceration."

                return {
                    "status": status,
                    "prediction": status,
                    "finding": finding,
                    "description": description,
                    "reason": reason,
                    "model": "ResNet50-DFU + OpenCV",
                    "screening_mode": "actual-upload",
                    "demo_mode": None,
                    "confidence": confidence,
                    "regions": cv_result.get("regions", []),
                    "image_metrics": cv_result.get("image_metrics", {}),
                    "disclaimer": cv_result.get("disclaimer"),
                    "probabilities": [round(x, 4) for x in [p0, p1, p2, p3]],
                }
        except Exception as exc:
            logger.exception("ResNet-50 inference failed, falling back to OpenCV result: %s", exc)

    return cv_result


def generate_care_plan(
    assessment_abnormal: bool,
    retina_abnormal: bool,
    foot_abnormal: bool,
    final_category: str = "",
) -> List[str]:
    plan: List[str] = []

    if final_category == "Healthy / Normal" or (not assessment_abnormal and not retina_abnormal and not foot_abnormal):
        plan.extend([
            "Maintain healthy lifestyle with at least 150 minutes of weekly moderate aerobic activity (brisk walking, swimming).",
            "Follow a balanced, low-glycemic Mediterranean-style diet rich in fiber, fresh vegetables, and lean proteins.",
            "Ensure optimal daily hydration (2.5 - 3.0 Liters) and maintain consistent sleep hygiene.",
            "Schedule annual comprehensive preventive diabetes screening and routine wellness checkups.",
        ])
    elif final_category == "Early Risk":
        plan.extend([
            "Reduce sugar-sweetened beverages and refined carbohydrates; favor high-fiber whole foods.",
            "Increase daily physical activity gradually to at least 150 minutes per week of moderate exercise.",
            "Maintain regular blood glucose monitoring and schedule follow-up screening within 3 to 6 months.",
            "Review weight, sleep, and stress factors to reduce future progression risk.",
        ])
    elif final_category == "Borderline":
        plan.extend([
            "Detailed medical consultation for HbA1c and fasting plasma glucose confirmation.",
            "Use a structured low-glycemic diet with portion control and reduced refined starches.",
            "Aim for 30 minutes of daily low-impact exercise and a consistent daily activity schedule.",
            "Monitor blood glucose, blood pressure, and symptoms with a structured log for clinical review.",
        ])
    else:  # Diabetic / High Risk
        plan.extend([
            "Urgent physician and endocrinologist consultation for formal diabetes evaluation and treatment planning.",
            "Request a full diagnostic panel including HbA1c, fasting plasma glucose, renal function, and lipid profile.",
            "Implement intensive lifestyle modification, medication review, and cardiovascular risk reduction.",
            "Monitor blood glucose, blood pressure, and symptoms daily with close follow-up.",
        ])

    if assessment_abnormal:
        plan.extend([
            "Prioritize weight management, meal timing, and regular blood sugar tracking to improve long-term metabolic control.",
            "Discuss risk factors with your clinician and review whether additional lab testing is needed.",
        ])

    if retina_abnormal:
        plan.extend([
            "Arrange an urgent dilated eye examination or retinal specialist review for detected retinal findings.",
            "Maintain strict glycemic and blood pressure control to reduce progression of eye disease.",
        ])

    if foot_abnormal:
        plan.extend([
            "Consult a podiatrist or diabetic foot specialist for a clinical foot assessment and wound management plan.",
            "Use protective, pressure-relieving footwear and avoid walking barefoot to protect the foot.",
            "Perform daily foot inspections and keep the area clean, dry, and protected from injury or infection.",
        ])

    return plan


def predict_final(
    assessment_result: Dict[str, Any],
    retina_result: Dict[str, Any],
    foot_result: Dict[str, Any],
) -> Dict[str, Any]:
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

    foot_label = " ".join(
        str(foot_result.get(key, "")).lower()
        for key in ("status", "prediction", "risk_level")
    )
    normalized_foot_status = _normalize_foot_status(
        foot_result.get("status") or foot_result.get("prediction")
    )
    foot_ulcer_suspected = (
        normalized_foot_status == "SEVERE FINDING"
        or "ulcer suspected" in foot_label
        or "severe finding" in foot_label
        or "severe foot ulcer detected" in foot_label
    )
    foot_inconclusive = (
        "inconclusive" in foot_label
        or normalized_foot_status == "INCONCLUSIVE"
    )

    retina_abnormal = _is_retina_abnormal(retina_result)
    # Final combined outcome is driven by the exact multimodal matrix, not the
    # individual module verdicts alone.
    assess_abnormal = _is_assessment_abnormal(assessment_result)
    foot_abnormal = _is_foot_abnormal(foot_result)
    abnormal_count = int(assess_abnormal) + int(retina_abnormal) + int(foot_abnormal)

    # STRICT MULTIMODAL DECISION MATRIX
    # 0 abnormal -> Healthy / Normal (0–5%)
    # 1 abnormal -> Early Risk (15–25%)
    # 2 abnormal -> Borderline (40–50%)
    # 3 abnormal -> Diabetic / High Risk (70–75%)
    if abnormal_count == 0:
        demo_category = "Healthy / Normal"
        demo_score = 5.0
        demo_risk_level = "healthy"
    elif abnormal_count == 1:
        demo_category = "Early Risk"
        demo_score = 20.0
        demo_risk_level = "prediabetic"
    elif abnormal_count == 2:
        demo_category = "Borderline"
        demo_score = 45.0
        demo_risk_level = "borderline"
    else:
        demo_category = "Diabetic / High Risk"
        demo_score = 72.0
        demo_risk_level = "highRisk"

    # Keep the final combined status aligned with the centralized decision matrix.
    risk_level = demo_risk_level
    prediction_label = demo_category

    if foot_inconclusive:
        logger.info("Foot result is inconclusive; it is excluded from overall status.")

    retina_confidence = valid_percentage(retina_result.get("confidence"))
    foot_confidence = valid_percentage(foot_result.get("confidence"))

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

    care_plan = generate_care_plan(
        assess_abnormal,
        retina_abnormal,
        foot_abnormal,
        final_category=demo_category,
    )

    return {
        "assessment_score": round(assessment_score, 2),
        "assessment_class_probabilities": class_probabilities,
        "assessment_explanation": assessment_result.get("explanation"),
        "assessment_probability_calibration": assessment_result.get(
            "probability_calibration"
        ),
        "assessment_abnormal": assess_abnormal,
        "retina_result": retina_prediction,
        "retina_risk_percentage": None,
        "retina_confidence": retina_confidence,
        "retina_abnormal": retina_abnormal,
        "foot_result": foot_prediction,
        "foot_risk_percentage": None,
        "foot_confidence": foot_confidence,
        "foot_abnormal": foot_abnormal,
        "abnormal_inputs_count": abnormal_count,
        "overall_demo_risk_score": demo_score,
        "demo_risk_score": demo_score,
        "demo_prediction_label": demo_category,
        "demo_risk_level": demo_risk_level,
        "overall_risk_percentage": demo_score,
        "risk_percentage": demo_score,
        "risk_level": risk_level,
        "prediction_label": prediction_label,
        "care_plan": care_plan,
        "multimodal_demo_matrix": {
            "category": demo_category,
            "overall_demo_risk_score": demo_score,
            "demo_risk_level": demo_risk_level,
            "abnormal_inputs_count": abnormal_count,
            "score_band": "0-5%" if abnormal_count == 0 else ("15-25%" if abnormal_count == 1 else ("40-50%" if abnormal_count == 2 else "70-75%")),
        },
        "score_disclaimer": (
            "The overall demo risk score is a competition demonstration metric "
            "derived from the centralized multimodal decision matrix, distinct from "
            "individual model clinical probabilities."
        ),
    }
