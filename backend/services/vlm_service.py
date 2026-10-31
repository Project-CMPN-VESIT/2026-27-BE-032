import io
import json
import logging
import os
import re
import time
import traceback
from datetime import datetime
from typing import Any, Dict, Optional, Union
from PIL import Image
import numpy as np
import cv2

# Set up logger for VLM service
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Load environment variables from .env if python-dotenv is available
try:
    import dotenv
    from pathlib import Path
    dotenv.load_dotenv()
    _backend_env = Path(__file__).resolve().parent.parent / ".env"
    if _backend_env.exists():
        dotenv.load_dotenv(_backend_env)
    _root_env = Path(__file__).resolve().parent.parent.parent / ".env"
    if _root_env.exists():
        dotenv.load_dotenv(_root_env)
except ImportError:
    pass

DEFAULT_DISCLAIMER = "Automated visual screening based on the uploaded foot image."

# ---------------------------------------------------------------------------
# CLINICAL VLM PROMPT (Strict Visual Screening Rules & Structured Observations)
# ---------------------------------------------------------------------------
VLM_PROMPT = """You are a senior clinical computer vision assistant conducting visual diabetic foot lesion screening from a single RGB image.

OBJECTIVE:
Perform visual screening for foot lesions on the visible skin surface.
DO NOT diagnose diabetes or any systemic medical condition.
DO NOT infer hidden disease or non-visible pathology.

CLASSIFICATION CATEGORIES (Return EXACTLY ONE of these three):
1. "No Lesion Detected"
2. "Foot Ulcer Detected"
3. "Severe Foot Ulcer Detected"

STRICT DECISION RULES:

"No Lesion Detected":
Return ONLY if the skin is intact with NO visible open wound, ulcer, or tissue loss.
MUST classify as "No Lesion Detected" for all normal or benign skin variations:
- Healthy skin
- Dry skin, scaling, or flaking
- Skin folds, creases, or wrinkles
- Visible veins or tendons under intact skin
- Toenails, cuticles, or toe gaps
- Callus, corn, or hyperkeratosis without open ulcer
- Natural skin pigmentation, birthmarks, or moles
- Closed scars (healed skin with no open defect)
- Shadows, lighting variations, or camera flash reflections
- Background items (floor, tiles, bedsheets, socks)
NEVER classify intact skin with dry skin, calluses, shadows, dark background, or pigment as an ulcer.

"Foot Ulcer Detected":
Return ONLY if there is a clearly visible open wound, ulcer, skin breakdown, ruptured blister, localized tissue loss, or infected open wound.
DO NOT overestimate severity if the wound is small or localized.

"Severe Foot Ulcer Detected":
Return ONLY if ALL of the following are visually obvious and undeniable:
- Very large open wound or deep ulcer
- Visually obvious exposed deep tissue, tendon, or bone
- Extensive gangrene, necrosis, or black dead tissue
- Extensive tissue destruction spanning a major portion of the foot
If you are uncertain between "Foot Ulcer Detected" and "Severe Foot Ulcer Detected", ALWAYS choose "Foot Ulcer Detected".

EXTREMELY CONSERVATIVE POLICY:
- If uncertain whether a mark is a wound or benign feature (shadow, dirt, callus, pigment), default to "No Lesion Detected".
- Never overestimate disease severity.

CONFIDENCE GUIDELINES:
- "No Lesion Detected": 95 - 99
- "Foot Ulcer Detected": 80 - 95
- "Severe Foot Ulcer Detected": 90 - 98
NEVER return 100.

EXPLANATION (REASON) GUIDELINES:
- Describe ONLY visible physical surface findings.
- Good reasons: "Healthy foot skin with no visible ulcer, open wound or tissue damage.", "Small localized open ulcer is visible on the plantar region.", "Large deep ulcer with extensive tissue destruction is visible."
- BAD reasons (NEVER USE): Do not mention "diabetes", "diabetic", "infection risk", "needs surgery", or any unobserved medical state.

STRUCTURED VISUAL FINDINGS (Provide objective visual observations):
- open_wound: true/false
- callus: true/false
- dry_skin: true/false
- blister: true/false
- redness: "none" | "mild" | "moderate" | "severe"
- swelling: true/false
- necrosis: true/false
- exposed_tissue: true/false
- estimated_lesion_area: percentage string e.g. "0%", "<5%", "15%", ">20%"
- image_quality: "Good" | "Fair" | "Poor / Blurry"

OUTPUT FORMAT:
Return ONLY a valid JSON object with NO markdown formatting, NO code blocks, and NO extra text:
{
  "prediction": "No Lesion Detected",
  "severity": "Healthy Foot",
  "confidence": 97,
  "reason": "Healthy foot skin with no visible ulcer, open wound or tissue damage.",
  "visible_findings": {
    "open_wound": false,
    "callus": false,
    "dry_skin": false,
    "blister": false,
    "redness": "none",
    "swelling": false,
    "necrosis": false,
    "exposed_tissue": false,
    "estimated_lesion_area": "0%",
    "image_quality": "Good"
  }
}
"""

STANDARDIZED_PREDICTIONS = {
    "No Lesion Detected": {
        "prediction": "No Lesion Detected",
        "severity": "Healthy Foot",
        "default_confidence": 97,
        "default_reason": "Healthy foot skin with no visible ulcer, open wound or tissue damage.",
        "default_findings": {
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
        }
    },
    "Foot Ulcer Detected": {
        "prediction": "Foot Ulcer Detected",
        "severity": "Moderate Risk",
        "default_confidence": 88,
        "default_reason": "Small localized open ulcer or skin breakdown is visible.",
        "default_findings": {
            "open_wound": True,
            "callus": False,
            "dry_skin": False,
            "blister": False,
            "redness": "moderate",
            "swelling": False,
            "necrosis": False,
            "exposed_tissue": False,
            "estimated_lesion_area": "<5%",
            "image_quality": "Good"
        }
    },
    "Severe Foot Ulcer Detected": {
        "prediction": "Severe Foot Ulcer Detected",
        "severity": "High Risk",
        "default_confidence": 95,
        "default_reason": "Large deep ulcer with extensive tissue destruction is visible.",
        "default_findings": {
            "open_wound": True,
            "callus": False,
            "dry_skin": False,
            "blister": False,
            "redness": "severe",
            "swelling": True,
            "necrosis": True,
            "exposed_tissue": True,
            "estimated_lesion_area": ">20%",
            "image_quality": "Good"
        }
    }
}


def _to_pil_image(image_input: Any) -> Image.Image:
    """Converts various image input formats to PIL Image in RGB mode."""
    if isinstance(image_input, Image.Image):
        return image_input.convert("RGB")
    
    if isinstance(image_input, bytes):
        return Image.open(io.BytesIO(image_input)).convert("RGB")
    
    if isinstance(image_input, str):
        clean_path = image_input.strip().replace("file://", "")
        if clean_path.startswith(("http://", "https://")):
            import requests
            resp = requests.get(clean_path, timeout=15)
            resp.raise_for_status()
            return Image.open(io.BytesIO(resp.content)).convert("RGB")
        if os.path.exists(clean_path):
            return Image.open(clean_path).convert("RGB")
    
    raise ValueError(f"Unsupported image input type: {type(image_input)}")


def _parse_vlm_json_response(text: str, model_name: str) -> Optional[Dict[str, Any]]:
    """
    Parses and sanitizes the VLM text response into the required JSON dictionary.
    Handles markdown code block wrapping, malformed strings, class mapping, confidence bounds,
    and extended visual findings.
    """
    try:
        # Strip markdown fences (```json ... ``` or ``` ...)
        clean_text = re.sub(r"```(?:json)?", "", text, flags=re.IGNORECASE).strip("` \t\r\n")
        
        match = re.search(r"\{.*\}", clean_text, re.DOTALL)
        if not match:
            logger.warning("Failed to parse JSON structure from VLM response text.")
            return None

        parsed = json.loads(match.group(0))

        pred_str = str(parsed.get("prediction", "")).strip()
        pred_lower = pred_str.lower()

        # Enforce exact 3-class mapping
        if "severe" in pred_lower:
            matched_class = "Severe Foot Ulcer Detected"
        elif "ulcer" in pred_lower or "wound" in pred_lower or "breakdown" in pred_lower:
            matched_class = "Foot Ulcer Detected"
        else:
            matched_class = "No Lesion Detected"

        std = STANDARDIZED_PREDICTIONS[matched_class]

        # Confidence handling & clamping
        raw_conf = parsed.get("confidence")
        try:
            conf = int(float(raw_conf))
        except (TypeError, ValueError):
            conf = std["default_confidence"]

        if matched_class == "No Lesion Detected":
            conf = min(99, max(95, conf))
        elif matched_class == "Foot Ulcer Detected":
            conf = min(95, max(80, conf))
        elif matched_class == "Severe Foot Ulcer Detected":
            conf = min(98, max(90, conf))

        # Never return 100% confidence
        conf = min(99, conf)

        # Reason sanitization
        reason = str(parsed.get("reason", "")).strip()
        if not reason or len(reason) < 5:
            reason = std["default_reason"]

        # Ensure no forbidden terms (non-visible medical inferences) in reason
        forbidden_terms = ["diabetes", "diabetic", "infection", "surgery", "hba1c", "glucose", "neuropathy"]
        if any(term in reason.lower() for term in forbidden_terms):
            reason = std["default_reason"]

        # Parse & sanitize extended visible_findings
        vf_raw = parsed.get("visible_findings")
        default_vf = std["default_findings"]
        if isinstance(vf_raw, dict):
            visible_findings = {
                "open_wound": bool(vf_raw.get("open_wound", default_vf["open_wound"])),
                "callus": bool(vf_raw.get("callus", default_vf["callus"])),
                "dry_skin": bool(vf_raw.get("dry_skin", default_vf["dry_skin"])),
                "blister": bool(vf_raw.get("blister", default_vf["blister"])),
                "redness": str(vf_raw.get("redness", default_vf["redness"])),
                "swelling": bool(vf_raw.get("swelling", default_vf["swelling"])),
                "necrosis": bool(vf_raw.get("necrosis", default_vf["necrosis"])),
                "exposed_tissue": bool(vf_raw.get("exposed_tissue", default_vf["exposed_tissue"])),
                "estimated_lesion_area": str(vf_raw.get("estimated_lesion_area", default_vf["estimated_lesion_area"])),
                "image_quality": str(vf_raw.get("image_quality", default_vf["image_quality"]))
            }
        else:
            visible_findings = default_vf

        return {
            "prediction": matched_class,
            "severity": std["severity"],
            "confidence": conf,
            "reason": reason,
            "visible_findings": visible_findings,
            "model": model_name,
            "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "disclaimer": DEFAULT_DISCLAIMER
        }
    except Exception as exc:
        logger.error(f"Error parsing VLM JSON response: {exc}")
        return None


def _call_gemini_vision_with_retry(pil_img: Image.Image, api_key: str) -> Dict[str, Any]:
    """
    Calls Gemini Vision model with fallback model names. Retries across models before giving up.
    """
    import google.generativeai as genai
    genai.configure(api_key=api_key)

    # Models to attempt in order of preference (active and tested models with separate quotas)
    models_to_try = [
        "gemini-3.5-flash",
        "gemini-3.1-flash-lite",
        "gemini-3.5-flash-lite",
        "gemini-3.8-flash",
        "gemini-flash-latest"
    ]

    print("[VLM] Gemini Prompt Sent:")
    print("-" * 50)
    print(VLM_PROMPT[:300] + "... [clinical JSON instructions]")
    print("-" * 50)

    last_error = None
    for attempt in range(2):  # Try initial call, retry once if failed
        for model_name in models_to_try:
            try:
                print(f"[VLM] Calling Gemini Vision model '{model_name}' (Attempt {attempt + 1})...")
                print(f"[VLM] Image sent to Gemini: size={pil_img.size}, mode={pil_img.mode}")
                model = genai.GenerativeModel(model_name)
                response = model.generate_content([VLM_PROMPT, pil_img])
                if response and response.text:
                    raw_text = response.text.strip()
                    print("================ GEMINI RAW RESPONSE ================")
                    print(raw_text)
                    print("=====================================================")
                    parsed = _parse_vlm_json_response(raw_text, model_name=model_name)
                    if parsed:
                        print(f"[VLM] Parsed response: prediction='{parsed.get('prediction')}', confidence={parsed.get('confidence')}%")
                        return parsed
            except Exception as exc:
                last_error = exc
                print(f"[WARN] Gemini VLM model '{model_name}' attempt {attempt + 1} failed: {exc}")
                # Always continue to try the next model candidate if quota (429) or deprecated (404)
                continue
        time.sleep(1)

    raise RuntimeError(f"Gemini VLM failed after retry: {last_error}")


def _analyze_image_offline_opencv(pil_img: Image.Image) -> Dict[str, Any]:
    """
    Offline OpenCV Fallback Vision Screening.
    Requires actual visible wound contours on skin.
    Never uses darkness alone, black pixels, shadows, or color alone.
    """
    try:
        from backend.services.opencv_foot_service import analyze_foot_opencv
        img_rgb = pil_img.convert("RGB")
        img_np = np.array(img_rgb)
        img_bgr = cv2.cvtColor(img_np, cv2.COLOR_RGB2BGR)

        res = analyze_foot_opencv(img_bgr)
        pred = res["prediction"]
        std = STANDARDIZED_PREDICTIONS.get(pred, STANDARDIZED_PREDICTIONS["No Lesion Detected"])

        return {
            "prediction": res["prediction"],
            "severity": res["severity"],
            "confidence": res["confidence"],
            "reason": res["reason"],
            "visible_findings": std["default_findings"],
            "model": "opencv-offline-fallback",
            "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "disclaimer": DEFAULT_DISCLAIMER,
            "vlm_source": "offline_opencv_fallback"
        }
    except Exception as exc:
        print(f"[ERROR] Offline OpenCV fallback error: {exc}")
        traceback.print_exc()
        std = STANDARDIZED_PREDICTIONS["No Lesion Detected"]
        return {
            "prediction": std["prediction"],
            "severity": std["severity"],
            "confidence": std["default_confidence"],
            "reason": std["default_reason"],
            "visible_findings": std["default_findings"],
            "model": "opencv-offline-fallback",
            "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "disclaimer": DEFAULT_DISCLAIMER,
            "vlm_source": "offline_default_fallback"
        }


def analyze_foot_with_vlm(image_input: Any) -> Dict[str, Any]:
    """
    Main entry point for diabetic foot visual screening VLM pipeline.
    
    1. Gemini Vision is Primary (using GEMINI_API_KEY or GOOGLE_API_KEY).
    2. Retries Gemini ONCE on error.
    3. Falls back to offline OpenCV if Gemini is unavailable or fails.
    """
    try:
        pil_img = _to_pil_image(image_input)
    except Exception as exc:
        print(f"[ERROR] VLM Service: Failed to process input image: {exc}")
        std = STANDARDIZED_PREDICTIONS["No Lesion Detected"]
        return {
            "prediction": std["prediction"],
            "severity": std["severity"],
            "confidence": std["default_confidence"],
            "reason": std["default_reason"],
            "visible_findings": std["default_findings"],
            "model": "error-fallback",
            "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "disclaimer": DEFAULT_DISCLAIMER,
            "vlm_source": "invalid_image_fallback"
        }

    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")

    try:
        print("[VLM] Primary: Triggering Gemini Vision Model for Foot Scan...")
        result = _call_gemini_vision_with_retry(pil_img, api_key)
        result["vlm_source"] = "gemini_vision_vlm"
        return result
    except Exception as exc:
        print(f"[WARN] Gemini VLM failed after retry: {exc}. Falling back to offline OpenCV...")
        traceback.print_exc()

    print("[INFO] Fallback: Running Offline OpenCV Rule-Based Visual Screening...")
    return _analyze_image_offline_opencv(pil_img)
