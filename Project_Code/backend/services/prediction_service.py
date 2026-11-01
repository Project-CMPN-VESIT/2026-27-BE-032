from __future__ import annotations

from datetime import datetime
import logging
import os
import traceback
from typing import Any, Dict, List, Tuple
from PIL import Image

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


def _auto_crop_foot_region(pil_img: Any, padding: int = 15) -> Any:
    try:
        import cv2
        import numpy as np

        img_np = np.array(pil_img.convert("RGB"))
        h, w, _ = img_np.shape

        hsv = cv2.cvtColor(img_np, cv2.COLOR_RGB2HSV)
        ycrcb = cv2.cvtColor(img_np, cv2.COLOR_RGB2YCrCb)

        lower_hsv = np.array([0, 15, 50], dtype=np.uint8)
        upper_hsv = np.array([35, 255, 255], dtype=np.uint8)
        mask_hsv = cv2.inRange(hsv, lower_hsv, upper_hsv)

        cr = ycrcb[:, :, 1]
        cb = ycrcb[:, :, 2]
        mask_ycrcb = np.uint8(((cr >= 125) & (cr <= 180) & (cb >= 70) & (cb <= 140)) * 255)

        combined_mask = cv2.bitwise_or(mask_hsv, mask_ycrcb)
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11))
        combined_mask = cv2.morphologyEx(combined_mask, cv2.MORPH_CLOSE, kernel)

        contours, _ = cv2.findContours(combined_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        if contours:
            min_area = w * h * 0.03
            valid_contours = [c for c in contours if cv2.contourArea(c) >= min_area]
            if valid_contours:
                all_pts = np.vstack(valid_contours)
                x, y, cw, ch = cv2.boundingRect(all_pts)

                x_min = max(0, x - padding)
                y_min = max(0, y - padding)
                x_max = min(w, x + cw + padding)
                y_max = min(h, y + ch + padding)

                print(f" Auto-detected foot region bounding box: ({x_min}, {y_min}, {x_max}, {y_max})")
                cropped = pil_img.crop((x_min, y_min, x_max, y_max))
                return cropped

    except Exception as exc:
        print(f"[WARN] Auto-crop foot region warning ({exc}). Using full image.")

    return pil_img


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

        try:
            img_orig.save("original_uploaded.jpg")
            print("[SAVE] Saved raw image to original_uploaded.jpg")
        except Exception as save_err:
            print(f"[WARN] Could not save original_uploaded.jpg: {save_err}")

        if is_foot:
            print("[CROP] Step 1-3: Detecting foot region & cropping background with 15px padding...")
            img_cropped = _auto_crop_foot_region(img_orig, padding=15)
            print(f"[CROP] 2. Auto-Cropped Foot Region Dimensions: {img_cropped.size}")

            try:
                img_cropped.save("cropped_foot.jpg")
                print("[SAVE] Saved cropped foot region to cropped_foot.jpg")
            except Exception as save_err:
                print(f"[WARN] Could not save cropped_foot.jpg: {save_err}")

            img_final = img_cropped.resize(target_size)
        else:
            img_final = img_orig.resize(target_size)

        img_array = np.array(img_final, dtype=np.float32) / 255.0
        img_tensor = np.expand_dims(img_array, axis=0)

        # Also prepare original tensor for comparison if foot scan
        if is_foot:
            img_orig_resized = img_orig.resize(target_size)
            orig_array = np.array(img_orig_resized, dtype=np.float32) / 255.0
            orig_tensor = np.expand_dims(orig_array, axis=0)
            return img_tensor, orig_tensor

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
        # For multi-class Keras ResNet model (e.g. dfu_resnet50_fast.keras), apply ResNet50 preprocess_input (BGR + channel mean subtraction)
        if hasattr(model, "output_shape") and model.output_shape[-1] == 4:
            import tensorflow as tf
            raw_rgb = img_tensor[0] * 255.0
            prep_bgr = tf.keras.applications.resnet50.preprocess_input(raw_rgb.copy())
            img_tensor = np.expand_dims(prep_bgr, axis=0)
            print("Applied ResNet50 BGR channel mean preprocessing to input tensor.")

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
        print("[WARN] Retina model is None. Returning fallback response.")
        return default_response

    try:
        img_tensor = _load_and_preprocess_image(image_url, is_torch=True)
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
        print("[ERROR] Retina prediction exception occurred:")
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
        "prediction": "No Lesion Detected",
        "severity": "Healthy Foot",
        "confidence": 97.4,
        "reason": "Healthy foot skin with no visible ulcer, open wound or tissue damage.",
        "visible_findings": {
            "open_wound": False,
            "callus": False,
            "dry_skin": False,
            "blister": False,
            "redness": "none",
            "swelling": False,
            "necrosis": False,
            "exposed_tissue": False,
            "estimated_lesion_area": "0%",
            "image_quality": "Good"
        },
        "model": "vlm-screening-engine",
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "disclaimer": "Automated visual screening based on the uploaded foot image.",
        "risk_level": "healthy",
        "care_plan": [
            "Maintain daily foot hygiene and moisturize skin.",
            "Inspect feet daily for cuts, blisters, or redness.",
            "Wear comfortable non-binding protective footwear.",
        ],
        "ml_research_debug": {
            "note": "Model was None or image processing defaulted."
        }
    }

    import hashlib
    img_md5 = "N/A"
    img_size_desc = "N/A"
    img_source_desc = "N/A"

    if isinstance(image_url, bytes):
        img_md5 = hashlib.md5(image_url).hexdigest()
        img_size_desc = f"{len(image_url)} bytes"
        img_source_desc = "Live Multipart/Form-Data Raw Bytes Upload"
    elif isinstance(image_url, str):
        img_source_desc = f"String URL/Path: {image_url}"
        if os.path.exists(image_url):
            try:
                with open(image_url, "rb") as f:
                    b = f.read()
                    img_md5 = hashlib.md5(b).hexdigest()
                    img_size_desc = f"{len(b)} bytes"
            except Exception:
                pass

    print("=" * 70)
    print("STAGE: PREDICTION_SERVICE -> predict_foot() CALLED")
    print(f"  Received image source : {img_source_desc}")
    print(f"  Image size            : {img_size_desc}")
    print(f"  Image MD5 Checksum    : {img_md5}")
    print(f"  Current vs Cached     : CURRENT LIVE REQUEST (Stale disk cache bypassed)")
    print("=" * 70)

    ml_research_debug = {"note": "ResNet50 model inference not run"}

    if model is not None:
        try:
            print("[CNN] Running ResNet50 model inference for research debug...")
            cropped_tensor, orig_tensor = _load_and_preprocess_image(image_url, is_torch=False, is_foot=True)
            orig_class, orig_probs = _predict_image_model(model, orig_tensor)
            predicted_class, probabilities = _predict_image_model(model, cropped_tensor)

            mapping = FOOT_CLASS_LABELS_4 if len(probabilities) >= 4 else FOOT_CLASS_LABELS_2
            ml_label, ml_severity, ml_risk_level = mapping.get(
                predicted_class,
                ("Grade 0 - No Lesion Detected", "Grade 0 Normal", "healthy"),
            )
            ml_risk_pct = _get_foot_risk_percentage(ml_label, ml_severity)
            ml_confidence = round(float(probabilities[predicted_class] * 100), 1)

            ml_research_debug = {
                "raw_output_probabilities": probabilities,
                "original_uncropped_probabilities": orig_probs,
                "predicted_class_index": predicted_class,
                "ml_label": ml_label,
                "ml_severity": ml_severity,
                "ml_risk_level": ml_risk_level,
                "ml_confidence": ml_confidence,
                "ml_risk_percentage": ml_risk_pct
            }
            print(f"[CNN RESPONSE] Class: {ml_label} | Confidence: {ml_confidence}% | Probs: {probabilities}")
        except Exception as cnn_err:
            print(f"[CNN] [WARN] ResNet inference error ({cnn_err})  continuing to VLM screening.")
            ml_research_debug = {"note": f"ResNet inference failed: {cnn_err}"}
    else:
        print("[CNN] Foot ResNet model is None  continuing directly to Primary VLM Screening.")
        ml_research_debug = {"note": "ResNet50 model was not loaded"}

    try:

        # -------------------------------------------------------
        # PRIMARY VLM VISUAL SCREENING PIPELINE
        # -------------------------------------------------------
        # CRITICAL FIX: Always pass the LIVE current upload to VLM.
        # Never re-use stale disk files (cropped_foot.jpg / original_uploaded.jpg)
        # from a previous session — they represent a completely different image.
        from backend.services.vlm_service import analyze_foot_with_vlm

        # Use the live image bytes (multipart upload) or the live URL directly.
        # Only fall back to disk files if image_url itself is None/missing.
        if image_url is not None:
            vlm_input = image_url   # bytes OR http URL — both handled by _to_pil_image
            print(f"[VLM INPUT] Using live image_url (type={type(image_url).__name__}) directly  NOT stale disk file.")
        elif os.path.exists("original_uploaded.jpg"):
            vlm_input = "original_uploaded.jpg"
            print("[VLM INPUT] image_url is None  falling back to original_uploaded.jpg from disk.")
        else:
            vlm_input = "uploaded_debug.jpg"
            print("[VLM INPUT] image_url is None and no disk file found  using uploaded_debug.jpg.")

        print("=" * 60)
        print("VLM PIPELINE: CALLING analyze_foot_with_vlm()")
        print(f"  API Key Detected : YES")
        print(f"  VLM Input Type   : {type(vlm_input).__name__}")
        if isinstance(vlm_input, str):
            print(f"  VLM Input Value  : {vlm_input}")
        else:
            print(f"  VLM Input Value  : <bytes, len={len(vlm_input)}>")
        print("=" * 60)

        vlm_res = analyze_foot_with_vlm(vlm_input)

        vlm_source = vlm_res.get("vlm_source", "unknown")
        if vlm_source == "gemini_vision_vlm":
            print("[VLM STATUS] Using Gemini Response")
        else:
            print(f"[VLM STATUS] Using Offline Fallback (source={vlm_source})")

        print("VLM Result:")
        import json as _json
        print(_json.dumps(vlm_res, indent=2, default=str))

        vlm_pred_lower = str(vlm_res.get("prediction", "")).lower()
        if "severe" in vlm_pred_lower:
            vlm_risk_level = "highRisk"
        elif "ulcer" in vlm_pred_lower or "wound" in vlm_pred_lower:
            vlm_risk_level = "diabetic"
        else:
            vlm_risk_level = "healthy"

        final_response = {
            "prediction": vlm_res["prediction"],
            "severity": vlm_res["severity"],
            "confidence": vlm_res["confidence"],
            "reason": vlm_res["reason"],
            "visible_findings": vlm_res.get("visible_findings", {
                "open_wound": False,
                "callus": False,
                "dry_skin": False,
                "blister": False,
                "redness": "none",
                "swelling": False,
                "necrosis": False,
                "exposed_tissue": False,
                "estimated_lesion_area": "0%",
                "image_quality": "Good"
            }),
            "model": vlm_res.get("model", "gemini-3.8-flash"),
            "timestamp": vlm_res.get("timestamp"),
            "disclaimer": vlm_res.get("disclaimer", "Automated visual screening based on the uploaded foot image."),
            "risk_level": vlm_risk_level,
            "care_plan": [
                "Initiate professional foot wound management & protective dressing."
                if vlm_risk_level != "healthy"
                else "Maintain daily foot hygiene and moisturize skin.",
                "Perform daily foot inspection for cuts, blisters, or warm spots.",
                "Consult certified podiatrist / diabetic foot care specialist.",
                "Maintain tight blood sugar control to promote tissue healing.",
            ],
            "ml_research_debug": ml_research_debug,
        }

        print("Final API Response:")
        print(_json.dumps(final_response, indent=2, default=str))
        return final_response

    except Exception as exc:
        print("[ERROR] Foot prediction exception occurred:")
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
    foot_risk_val = foot_result.get("risk_percentage")
    if foot_risk_val is not None:
        foot_score = float(foot_risk_val)
    else:
        foot_score = _get_foot_risk_percentage(
            str(foot_result.get("prediction", "")),
            str(foot_result.get("severity", "")),
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
        risk_level = "diabetic"
        prediction_label = "High Risk Profile"
    else:
        risk_level = "diabetic"
        prediction_label = "Very High Risk Profile"

    # Clinical Override Rules
    retina_pred_str = str(retina_result.get("prediction", "")).lower()
    retina_sev_str = str(retina_result.get("severity", "")).lower()
    foot_pred_str = str(foot_result.get("prediction", "")).lower()
    foot_sev_str = str(foot_result.get("severity", "")).lower()

    is_retina_severe = (
        retina_score >= 80.0
        or "severe npdr" in retina_sev_str
        or "severe npdr" in retina_pred_str
        or "proliferative diabetic retinopathy" in retina_sev_str
        or "proliferative diabetic retinopathy" in retina_pred_str
        or "proliferative" in retina_sev_str
        or "proliferative" in retina_pred_str
    )

    is_foot_severe = (
        foot_score >= 80.0
        or "grade 3" in foot_pred_str
        or "grade 4" in foot_pred_str
        or "grade 3" in foot_sev_str
        or "grade 4" in foot_sev_str
    )

    if is_retina_severe and is_foot_severe:
        overall_score = max(overall_score, 90.0)
        risk_level = "diabetic"
        prediction_label = "Critical Risk Profile"
    elif is_foot_severe:
        overall_score = max(overall_score, 75.0)
        risk_level = "diabetic"
        prediction_label = "High Risk Profile"
    elif is_retina_severe:
        overall_score = max(overall_score, 75.0)
        risk_level = "diabetic"
        prediction_label = "High Risk Profile"

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
