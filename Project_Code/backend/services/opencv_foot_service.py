"""Preliminary OpenCV analysis of uploaded foot images."""

from __future__ import annotations

import io
import logging
import os
from typing import Any, Dict

import cv2
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)

FOOT_DESCRIPTIONS = {
    "NORMAL": "OpenCV found no clear localized wound-like region in the uploaded image.",
    "MILD FINDING": "OpenCV found a small, localized region with combined wound-like visual features; clinical review is recommended.",
    "SEVERE FINDING": "OpenCV found a large or multiple wound-like regions; seek prompt clinical evaluation.",
    "INCONCLUSIVE": (
        "The image could not be assessed reliably. Upload a clear, well-lit image "
        "showing the foot area."
    ),
}

SCREENING_DISCLAIMER = (
    "Preliminary OpenCV visual screening only. Not clinically validated and not "
    "a medical diagnosis."
)

_MAX_IMAGE_BYTES = 12 * 1024 * 1024
_MAX_IMAGE_DIMENSION = 8192
_MAX_IMAGE_PIXELS = 40_000_000
_MIN_IMAGE_DIMENSION = 160
_MAX_ANALYSIS_DIMENSION = 1024
_MIN_BRIGHTNESS = 20.0
_MAX_BRIGHTNESS = 245.0
_MIN_CONTRAST = 5.0
_MIN_SHARPNESS = 1.1
_MIN_PHOTOGRAPHIC_ENTROPY = 3.0


def _decode_image(image_input: Any) -> tuple[np.ndarray, str]:
    if isinstance(image_input, Image.Image):
        source = io.BytesIO()
        image_input.convert("RGB").save(source, format="PNG")
        encoded = source.getvalue()
    elif isinstance(image_input, np.ndarray):
        if image_input.size == 0:
            raise ValueError("The uploaded image is empty.")
        if image_input.ndim not in {2, 3} or (
            image_input.ndim == 3 and image_input.shape[2] != 3
        ):
            raise ValueError("The image must have one or three color channels.")
        height, width = image_input.shape[:2]
        _validate_dimensions(width, height)
        if image_input.ndim == 2:
            image = cv2.cvtColor(image_input, cv2.COLOR_GRAY2BGR)
        else:
            image = image_input.copy()
        ok, buffer = cv2.imencode(".png", image)
        if not ok:
            raise ValueError("The uploaded image could not be encoded.")
        encoded = buffer.tobytes()
    elif isinstance(image_input, bytes):
        encoded = image_input
    elif isinstance(image_input, str):
        image_path = image_input.strip().replace("file://", "")
        if image_path.startswith(("http://", "https://")):
            raise ValueError(
                "OpenCV screening requires the uploaded image bytes, not a remote URL."
            )
        if not os.path.isfile(image_path):
            raise ValueError("The uploaded image path does not exist.")
        if os.path.getsize(image_path) > _MAX_IMAGE_BYTES:
            raise ValueError("The uploaded image exceeds the 12 MB limit.")
        with open(image_path, "rb") as image_file:
            encoded = image_file.read(_MAX_IMAGE_BYTES + 1)
    else:
        raise ValueError("The uploaded image format is not supported.")

    if not encoded:
        raise ValueError("The uploaded image is empty.")
    if len(encoded) > _MAX_IMAGE_BYTES:
        raise ValueError("The uploaded image exceeds the 12 MB limit.")

    try:
        with Image.open(io.BytesIO(encoded)) as header:
            image_format = header.format
            width, height = header.size
            if image_format not in {"JPEG", "PNG", "WEBP"}:
                raise ValueError("Upload a valid JPEG, PNG, or WebP image.")
            _validate_dimensions(width, height)
            header.verify()
    except (OSError, Image.DecompressionBombError) as exc:
        raise ValueError("The uploaded image is corrupt or cannot be decoded.") from exc

    image = cv2.imdecode(np.frombuffer(encoded, dtype=np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("The uploaded image is corrupt or cannot be decoded.")
    return image, image_format.lower()


def _validate_dimensions(width: int, height: int) -> None:
    if width > _MAX_IMAGE_DIMENSION or height > _MAX_IMAGE_DIMENSION:
        raise ValueError("Image dimensions must not exceed 8192 pixels.")
    if width * height > _MAX_IMAGE_PIXELS:
        raise ValueError("Image dimensions exceed the 40 megapixel limit.")


def _quality_issue(
    gray: np.ndarray, sharpness: float, entropy: float
) -> str | None:
    height, width = gray.shape[:2]
    if width < _MIN_IMAGE_DIMENSION or height < _MIN_IMAGE_DIMENSION:
        return "Image resolution is too low for reliable visual review."

    brightness = float(np.mean(gray))
    dark_fraction = float(np.mean(gray < 20))
    bright_fraction = float(np.mean(gray > 245))
    contrast = float(np.std(gray))

    if brightness < _MIN_BRIGHTNESS or dark_fraction > 0.65:
        return "The image is too dark to assess reliably."
    if brightness > _MAX_BRIGHTNESS or bright_fraction > 0.55:
        return "The image is overexposed and cannot be assessed reliably."
    if sharpness < _MIN_SHARPNESS:
        return "The image appears blurry or out of focus."
    if entropy < _MIN_PHOTOGRAPHIC_ENTROPY:
        return "There is insufficient photographic detail to assess the foot area."
    if contrast < _MIN_CONTRAST:
        return "The image has insufficient contrast for reliable visual review."
    return None


def _preprocess(image: np.ndarray) -> tuple[np.ndarray, Dict[str, Any], str | None]:
    height, width = image.shape[:2]
    scale = min(1.0, _MAX_ANALYSIS_DIMENSION / max(width, height))
    resized = cv2.resize(
        image,
        (max(1, round(width * scale)), max(1, round(height * scale))),
        interpolation=cv2.INTER_AREA if scale < 1 else cv2.INTER_LINEAR,
    )
    gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
    sharpness = float(cv2.Laplacian(gray, cv2.CV_32F).var())
    histogram = np.bincount(gray.ravel(), minlength=256).astype(np.float64)
    probabilities = histogram[histogram > 0] / gray.size
    entropy = float(-np.sum(probabilities * np.log2(probabilities)))
    quality_issue = _quality_issue(gray, sharpness, entropy)

    denoised = cv2.bilateralFilter(resized, d=5, sigmaColor=35, sigmaSpace=35)
    normalized = cv2.normalize(
        denoised, None, alpha=0, beta=255, norm_type=cv2.NORM_MINMAX
    )
    lab = cv2.cvtColor(normalized, cv2.COLOR_BGR2LAB)
    lab[:, :, 0] = cv2.createCLAHE(
        clipLimit=2.0, tileGridSize=(8, 8)
    ).apply(lab[:, :, 0])
    enhanced = cv2.cvtColor(lab, cv2.COLOR_LAB2BGR)

    gray_enhanced = cv2.cvtColor(enhanced, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray_enhanced, 50, 140)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    edges = cv2.morphologyEx(edges, cv2.MORPH_CLOSE, kernel)
    contours, _ = cv2.findContours(
        edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
    )

    quality = {
        "width": width,
        "height": height,
        "brightness_mean": round(float(np.mean(gray)), 2),
        "contrast_std": round(float(np.std(gray)), 2),
        "sharpness": round(sharpness, 2),
        "grayscale_entropy_bits": round(entropy, 3),
        "edge_density": round(float(np.mean(edges > 0)), 4),
        "contour_count": len(contours),
    }
    return enhanced, quality, quality_issue


def _localized_wound_regions(
    image: np.ndarray,
) -> tuple[list[Dict[str, Any]], Dict[str, float]]:
    height, width = image.shape[:2]
    lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB).astype(np.float32)
    lightness, chroma_a, chroma_b = cv2.split(lab)

    local_lightness = cv2.GaussianBlur(lightness, (0, 0), sigmaX=12, sigmaY=12)
    local_a = cv2.GaussianBlur(chroma_a, (0, 0), sigmaX=12, sigmaY=12)
    local_b = cv2.GaussianBlur(chroma_b, (0, 0), sigmaX=12, sigmaY=12)
    relative_darkness = local_lightness - lightness
    local_chroma_change = cv2.magnitude(chroma_a - local_a, chroma_b - local_b)

    fine_detail = cv2.absdiff(
        lightness,
        cv2.GaussianBlur(lightness, (0, 0), sigmaX=1.1, sigmaY=1.1),
    )
    local_texture = cv2.GaussianBlur(fine_detail, (0, 0), sigmaX=4, sigmaY=4)
    surrounding_texture = cv2.GaussianBlur(
        local_texture, (0, 0), sigmaX=12, sigmaY=12
    )
    texture_change = local_texture - surrounding_texture

    gradient_x = cv2.Sobel(lightness, cv2.CV_32F, 1, 0, ksize=3)
    gradient_y = cv2.Sobel(lightness, cv2.CV_32F, 0, 1, ksize=3)
    gradient_magnitude = cv2.magnitude(gradient_x, gradient_y)
    surrounding_gradient = cv2.GaussianBlur(
        gradient_magnitude, (0, 0), sigmaX=12, sigmaY=12
    )
    boundary_change = gradient_magnitude > np.maximum(
        24.0, surrounding_gradient * 1.8
    )

    color_and_texture = (
        (relative_darkness > 7.0)
        & (local_chroma_change > 7.0)
        & ((texture_change > 1.5) | boundary_change)
    )
    damaged_texture = (
        (relative_darkness > 12.0)
        & (texture_change > 2.5)
        & boundary_change
    )
    irregular_chromatic_damage = (
        (local_chroma_change > 16.0)
        & (relative_darkness > 4.0)
        & (texture_change > 2.5)
        & boundary_change
    )
    candidates = color_and_texture | damaged_texture | irregular_chromatic_damage

    mask = (candidates.astype(np.uint8) * 255)
    small_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
    region_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, small_kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, region_kernel)

    count, labels, stats, centroids = cv2.connectedComponentsWithStats(
        mask, connectivity=8
    )
    min_area = max(16, int(height * width * 0.0015))
    regions: list[Dict[str, Any]] = []
    for label in range(1, count):
        x, y, region_width, region_height, area = stats[label]
        if area < min_area:
            continue
        component = labels == label
        mean_darkness = float(np.mean(relative_darkness[component]))
        mean_chroma_change = float(np.mean(local_chroma_change[component]))
        mean_texture_change = float(np.mean(texture_change[component]))
        boundary_fraction = float(np.mean(boundary_change[component]))

        # A candidate must show multiple neighboring-relative wound cues.
        if not (
            (
                mean_darkness >= 7.0
                and mean_chroma_change >= 7.0
                and (mean_texture_change >= 1.5 or boundary_fraction >= 0.20)
            )
            or (
                mean_darkness >= 12.0
                and mean_texture_change >= 2.5
                and boundary_fraction >= 0.20
            )
            or (
                mean_chroma_change >= 16.0
                and mean_darkness >= 4.0
                and mean_texture_change >= 2.5
                and boundary_fraction >= 0.20
            )
        ):
            continue

        regions.append(
            {
                "label": "suspicious visual region",
                "x": float(round(x / width, 4)),
                "y": float(round(y / height, 4)),
                "width": float(round(region_width / width, 4)),
                "height": float(round(region_height / height, 4)),
                "area_fraction": float(round(area / (width * height), 5)),
                "bounding_box_fraction": float(
                    round((region_width * region_height) / (width * height), 5)
                ),
                "mean_relative_darkness": round(mean_darkness, 2),
                "mean_local_chroma_change": round(mean_chroma_change, 2),
                "mean_texture_change": round(mean_texture_change, 2),
                "boundary_fraction": round(boundary_fraction, 3),
            }
        )

    regions.sort(key=lambda region: region["area_fraction"], reverse=True)
    features = {
        "candidate_pixel_fraction": float(round(float(np.mean(candidates)), 5)),
        "localized_region_count": float(len(regions)),
        "localized_area_fraction": float(
            round(sum(region["area_fraction"] for region in regions), 5)
        ),
    }
    return regions, features


def analyze_foot_image(image_input: Any) -> Dict[str, Any]:
    """Run preliminary, non-clinically-validated OpenCV wound-region screening."""
    try:
        decoded, image_format = _decode_image(image_input)
        processed, quality, issue = _preprocess(decoded)
    except (ValueError, cv2.error, OSError, Image.DecompressionBombError) as exc:
        logger.info("Foot image was unsuitable for screening: %s", exc)
        return {
            "status": "INCONCLUSIVE",
            "prediction": "INCONCLUSIVE",
            "finding": "The uploaded image could not be assessed.",
            "description": FOOT_DESCRIPTIONS["INCONCLUSIVE"],
            "reason": str(exc),
            "model": "opencv-region-screening",
            "screening_mode": "actual-upload",
            "demo_mode": None,
            "confidence": None,
            "regions": [],
            "image_metrics": {},
            "disclaimer": SCREENING_DISCLAIMER,
        }

    if issue is not None:
        return {
            "status": "INCONCLUSIVE",
            "prediction": "INCONCLUSIVE",
            "finding": "Image quality is not sufficient for visual screening.",
            "description": FOOT_DESCRIPTIONS["INCONCLUSIVE"],
            "reason": issue,
            "model": "opencv-quality-check",
            "screening_mode": "actual-upload",
            "demo_mode": None,
            "confidence": None,
            "regions": [],
            "image_metrics": {"format": image_format, **quality},
            "disclaimer": SCREENING_DISCLAIMER,
        }

    regions, region_metrics = _localized_wound_regions(processed)
    local_area = float(region_metrics["localized_area_fraction"])
    region_count = len(regions)
    largest_region_fraction = max(
        (region["bounding_box_fraction"] for region in regions), default=0.0
    )
    largest_region_extent = max(
        (max(region["width"], region["height"]) for region in regions),
        default=0.0,
    )

    if region_count == 0:
        status = "NORMAL"
        finding = "No localized wound-like region was identified by OpenCV."
        reason = (
            "No region combined sufficient local darkness/chroma change with "
            "texture or boundary evidence. This does not rule out a medical problem."
        )
    elif (
        largest_region_fraction >= 0.15
        or local_area >= 0.07
        or (largest_region_extent >= 0.45 and local_area >= 0.035)
        or (region_count >= 3 and local_area >= 0.025)
    ):
        status = "SEVERE FINDING"
        finding = (
            f"OpenCV identified {region_count} localized region(s) covering "
            f"{local_area * 100:.1f}% of the analyzed image."
        )
        reason = (
            "The combined local color, texture, and boundary features span a "
            "large area or multiple regions; image appearance alone cannot "
            "confirm wound depth or severity."
        )
    else:
        status = "MILD FINDING"
        finding = (
            f"OpenCV identified {region_count} small localized region(s) "
            f"covering {local_area * 100:.1f}% of the analyzed image."
        )
        reason = (
            "The combined local color, texture, and boundary features form a "
            "limited region. Have a clinician assess visible skin damage."
        )

    image_metrics: Dict[str, Any] = {
        "format": image_format,
        **quality,
        **region_metrics,
        "largest_region_extent_fraction": round(largest_region_extent, 5),
        "preprocessing": [
            "aspect-preserving resize",
            "bilateral denoising",
            "intensity normalization",
            "LAB luminance CLAHE enhancement",
            "local LAB/chroma and luminance comparison",
            "local texture and boundary analysis",
            "morphological opening/closing",
            "connected-component region analysis",
        ],
        "regions": regions,
    }
    return {
        "status": status,
        "prediction": status,
        "finding": finding,
        "description": FOOT_DESCRIPTIONS[status],
        "reason": reason,
        "model": "opencv-region-screening",
        "screening_mode": "actual-upload",
        "demo_mode": None,
        "confidence": None,
        "regions": regions,
        "image_metrics": image_metrics,
        "disclaimer": SCREENING_DISCLAIMER,
    }


def analyze_foot_opencv(image_input: Any) -> Dict[str, Any]:
    """Backward-compatible alias used by legacy callers and older diagnostic scripts."""
    return analyze_foot_image(image_input)
