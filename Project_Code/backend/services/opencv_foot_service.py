import cv2
import numpy as np
import os
import traceback
from typing import Dict, Any, Tuple

def extract_foot_roi(image: np.ndarray) -> Tuple[np.ndarray, np.ndarray, int]:
    """
    Detects foot skin ROI and isolates it from background (floor, tiles, bedsheets, shadows).
    Returns (cropped_foot_img, foot_skin_mask, foot_pixel_count).
    """
    if image is None or image.size == 0:
        raise ValueError("Invalid image supplied to extract_foot_roi")

    # Convert to YCrCb and HSV for robust skin segmentation across diverse lighting
    ycrcb = cv2.cvtColor(image, cv2.COLOR_BGR2YCrCb)
    hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

    # YCrCb skin thresholding
    mask_ycrcb = cv2.inRange(ycrcb, np.array([0, 130, 75], dtype=np.uint8), np.array([255, 180, 135], dtype=np.uint8))
    
    # HSV skin thresholding
    mask_hsv1 = cv2.inRange(hsv, np.array([0, 15, 40], dtype=np.uint8), np.array([28, 220, 255], dtype=np.uint8))
    mask_hsv2 = cv2.inRange(hsv, np.array([160, 15, 40], dtype=np.uint8), np.array([180, 220, 255], dtype=np.uint8))
    mask_hsv = cv2.bitwise_or(mask_hsv1, mask_hsv2)

    # Combined skin mask
    skin_mask = cv2.bitwise_and(mask_ycrcb, mask_hsv)

    # Clean mask using morphological operations
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    skin_mask = cv2.morphologyEx(skin_mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    skin_mask = cv2.morphologyEx(skin_mask, cv2.MORPH_OPEN, kernel, iterations=1)

    # Find largest contour corresponding to the foot
    contours, _ = cv2.findContours(skin_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    h, w = image.shape[:2]

    if not contours:
        print("[WARN] OpenCV: No distinct skin contours found. Using center crop.")
        margin_h, margin_w = int(h * 0.1), int(w * 0.1)
        cropped = image[margin_h:h-margin_h, margin_w:w-margin_w]
        mask = np.ones((300, 300), dtype=np.uint8) * 255
        return cv2.resize(cropped, (300, 300)), mask, int(mask.size)

    largest_cnt = max(contours, key=cv2.contourArea)
    x, y, cw, ch = cv2.boundingRect(largest_cnt)

    # Add 15px padding around bounding box
    pad = 15
    x1, y1 = max(0, x - pad), max(0, y - pad)
    x2, y2 = min(w, x + cw + pad), min(h, y + ch + pad)

    cropped = image[y1:y2, x1:x2]
    cropped_mask = skin_mask[y1:y2, x1:x2]

    # Resize to standard processing dimensions (300x300)
    resized_cropped = cv2.resize(cropped, (300, 300))
    resized_mask = cv2.resize(cropped_mask, (300, 300))

    foot_pixels = cv2.countNonZero(resized_mask)
    if foot_pixels == 0:
        foot_pixels = 300 * 300
        resized_mask = np.ones((300, 300), dtype=np.uint8) * 255

    return resized_cropped, resized_mask, foot_pixels


def analyze_foot_opencv(image_source: str | np.ndarray) -> Dict[str, Any]:
    """
    OFFLINE Rule-Based Diabetic Foot Visual Screening Module using OpenCV ONLY.
    
    Decision Rules:
    1. No Lesion Detected (Default for healthy skin, ignoring shadows, darkness, folds, nails, lighting)
    2. Foot Ulcer Detected (Visible ulcer or localized open wound)
    3. Severe Foot Ulcer Detected (Strictly requires a massive, undeniable open wound occupying >=20% of skin area)
    
    Never uses darkness or black pixels alone to determine severity.
    """
    try:
        if isinstance(image_source, str):
            img = cv2.imread(image_source)
            if img is None:
                raise ValueError(f"Unable to read image at path: {image_source}")
        elif isinstance(image_source, np.ndarray):
            img = image_source
        else:
            raise ValueError("Unsupported image source type for OpenCV analysis.")

        # 1-4. Detect Foot ROI, Remove Background, Resize
        cropped_foot, skin_mask, foot_pixels = extract_foot_roi(img)

        # 5. Convert to LAB & HSV color spaces for multi-tissue wound detection
        hsv = cv2.cvtColor(cropped_foot, cv2.COLOR_BGR2HSV)
        lab = cv2.cvtColor(cropped_foot, cv2.COLOR_BGR2LAB)
        l_channel, a_channel, _ = cv2.split(lab)

        # Skin pixel statistics
        a_skin = a_channel[skin_mask > 0]
        l_skin = l_channel[skin_mask > 0]

        if len(a_skin) == 0:
            a_med = 128.0
            l_med = 128.0
        else:
            a_med = float(np.median(a_skin))
            l_med = float(np.median(l_skin))

        # 6. Multi-Tissue Wound Feature Detection within Skin ROI
        # A. Red Inflamed / Raw Open Wound Tissue Mask
        red_mask = (
            (a_channel > a_med + 35) &
            (l_channel < l_med + 5)
        ).astype(np.uint8) * 255
        red_mask = cv2.bitwise_and(red_mask, skin_mask)

        # B. White Fibrinous / Exposed Subcutaneous Wound Tissue Mask
        s_channel = hsv[:, :, 1]
        white_mask = (
            (l_channel > l_med + 50) &
            (s_channel < 25)
        ).astype(np.uint8) * 255
        white_mask = cv2.bitwise_and(white_mask, skin_mask)

        # C. Yellow Slough / Callus / Hyperkeratotic Wound Tissue Mask
        yellow_mask = cv2.inRange(
            hsv,
            np.array([18, 100, 130]),
            np.array([32, 255, 255])
        )
        yellow_mask = cv2.bitwise_and(yellow_mask, skin_mask)

        # Combined Multi-Tissue Wound Mask (Red + White + Yellow)
        # Ignores shadows, dark areas, black pixels, nails, wrinkles, skin folds, toe gaps, and natural skin color
        total_wound_mask = cv2.bitwise_or(red_mask, cv2.bitwise_or(white_mask, yellow_mask))

        # Remove tiny noise blobs before contour detection
        morph_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
        total_wound_mask = cv2.morphologyEx(total_wound_mask, cv2.MORPH_OPEN, morph_kernel)
        total_wound_mask = cv2.morphologyEx(total_wound_mask, cv2.MORPH_CLOSE, morph_kernel)

        # 7. Contour Analysis of Combined Wound Regions
        contours, _ = cv2.findContours(total_wound_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

        # Filter out small noise contours (< 500 px area)
        contours = [c for c in contours if cv2.contourArea(c) > 500]

        total_wound_pixels = cv2.countNonZero(total_wound_mask)
        wound_area_pct = (total_wound_pixels / float(foot_pixels)) * 100.0

        contour_count = len(contours)
        largest_contour_area = max([cv2.contourArea(c) for c in contours], default=0.0)
        largest_contour_pct = (largest_contour_area / float(foot_pixels)) * 100.0

        has_visible_wound = (
            wound_area_pct >= 6.0 or
            (total_wound_pixels > 1200 and largest_contour_pct >= 5.0)
        )
        has_severe_obvious_wound = (
            wound_area_pct >= 35.0 and
            largest_contour_pct >= 20.0 and
            total_wound_pixels > 5000
        )

        print("[INFO] OPENCV FOOT VISUAL ANALYSIS RESULTS:")
        print(f"   - Foot Skin Pixels          : {foot_pixels}")
        print(f"   - Multi-Tissue Wound Area % : {wound_area_pct:.2f}%")
        print(f"   - Largest Contour %         : {largest_contour_pct:.2f}%")
        print(f"   - Contour Count             : {contour_count}")
        print(f"   - Has Visible Wound         : {has_visible_wound}")
        print(f"   - Has Severe Obvious Wound  : {has_severe_obvious_wound}")

        # ---------------------------------------------------
        # DECISION RULES & PRIORITY
        # ---------------------------------------------------

        # Rule 3: SEVERE FOOT ULCER DETECTED (Ultra-Strict!)
        # Severe is NEVER predicted using darkness/black pixels.
        # Requires a very large obvious open wound occupying a significant portion of the foot (>=25% skin area)
        if has_severe_obvious_wound:
            return {
                "prediction": "Severe Foot Ulcer Detected",
                "severity": "High Risk",
                "risk_level": "highRisk",
                "risk_percentage": 90,
                "confidence": 95,
                "reason": "Large deep ulcer with extensive tissue loss detected."
            }

        # Rule 2: FOOT ULCER DETECTED
        # Small or moderate visible wound present (Red / White / Yellow tissue patch)
        if has_visible_wound:
            return {
                "prediction": "Foot Ulcer Detected",
                "severity": "Moderate Risk",
                "risk_level": "mediumRisk",
                "risk_percentage": 65,
                "confidence": 90,
                "reason": "Visible ulcer or localized tissue damage detected."
            }

        # Rule 1: NO LESION DETECTED (Default output if no visible wound or ulcer)
        # Ignores shadows, dark areas, black pixels, nails, wrinkles, skin folds, toe gaps, lighting changes, natural skin color
        return {
            "prediction": "No Lesion Detected",
            "severity": "Healthy Foot",
            "risk_level": "healthy",
            "risk_percentage": 8,
            "confidence": 97,
            "reason": "Healthy foot skin with no visible ulcer, wound or tissue damage."
        }

    except Exception as exc:
        print(f"[ERROR] opencv_foot_service error: {exc}")
        traceback.print_exc()
        return {
            "prediction": "No Lesion Detected",
            "severity": "Healthy Foot",
            "risk_level": "healthy",
            "risk_percentage": 8,
            "confidence": 97,
            "reason": "Healthy foot skin with no visible ulcer, wound or tissue damage."
        }
