from __future__ import annotations

import io
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image, ImageFilter

current_file = Path(__file__).resolve()
project_root = current_file.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from backend.services.prediction_service import (
    BRFSS_MEANS,
    BRFSS_STDS,
    FEATURE_KEYS,
    _build_brfss_feature_vector,
    assess_diabetes,
    predict_final,
    predict_foot,
)
from backend.services.opencv_foot_service import FOOT_DESCRIPTIONS, analyze_foot_image


def _foot_image_bytes(
    feature: str = "normal",
    *,
    blur_radius: int = 0,
    brightness: float = 1.0,
) -> bytes:
    y, x = np.indices((320, 320))
    if feature == "synthetic_drawing":
        image = np.empty((320, 320, 3), dtype=np.float64)
        image[:, :] = (210, 160, 135)
        distance = (x - 160) ** 2 + (y - 160) ** 2
        image[distance < 84**2] = (165, 12, 16)
        image[distance < 52**2] = (232, 198, 40)
        output = io.BytesIO()
        Image.fromarray(image.astype(np.uint8)).save(output, format="JPEG")
        return output.getvalue()

    illumination = 125 + 0.16 * x + 0.08 * y
    natural_skin_texture = (
        3.2 * np.sin(x / 8.0)
        + 2.4 * np.sin(y / 11.0)
        + 1.8 * np.sin((x + y) / 17.0)
        + 1.2 * np.sin((2 * x - y) / 29.0)
    )
    if feature == "natural_texture":
        natural_skin_texture += (
            4.0 * np.sin(x / 2.6) + 2.5 * np.sin((x + y) / 4.2)
        )
    skin = illumination + natural_skin_texture
    image = np.stack((skin + 20, skin + 4, skin - 15), axis=2)

    if feature == "shadow":
        shadow = np.clip((x - 120) / 80, 0, 1) * 20
        image -= shadow[:, :, None]
    elif feature == "pigmentation":
        pigmentation = (x - 175) ** 2 + (y - 160) ** 2 < 38**2
        image[pigmentation] += np.array((3, -3, 0))

    if feature in {"mild", "severe"}:
        radius = 27 if feature == "mild" else 85
        mark = (x - 160) ** 2 + (y - 160) ** 2 < radius**2
        mark_texture = np.random.default_rng(42).normal(0, 7, (320, 320, 3))
        damaged_skin = np.stack(
            (100 + mark_texture[:, :, 0], 24 + mark_texture[:, :, 1],
             22 + mark_texture[:, :, 2]),
            axis=2,
        )
        image[mark] = damaged_skin[mark]
    elif feature not in {
        "normal",
        "natural_texture",
        "shadow",
        "pigmentation",
    }:
        raise ValueError(f"Unknown test feature: {feature}")

    output = io.BytesIO()
    Image.fromarray(
        (image * brightness).clip(0, 255).astype(np.uint8)
    ).save(output, format="JPEG", quality=95)
    with Image.open(io.BytesIO(output.getvalue())) as decoded:
        processed = decoded.copy()
    if blur_radius:
        processed = processed.filter(ImageFilter.GaussianBlur(radius=blur_radius))
    result = io.BytesIO()
    processed.save(result, format="JPEG", quality=95)
    return result.getvalue()


@pytest.mark.parametrize(
    ("feature", "expected_status"),
    [
        ("normal", "NORMAL"),
        ("natural_texture", "NORMAL"),
        ("shadow", "NORMAL"),
        ("pigmentation", "NORMAL"),
        ("mild", "MILD FINDING"),
        ("severe", "SEVERE FINDING"),
    ],
)
def test_opencv_analyzes_actual_uploaded_image(
    feature: str, expected_status: str
) -> None:
    response = analyze_foot_image(_foot_image_bytes(feature))

    assert response["status"] == expected_status
    assert response["prediction"] == expected_status
    assert response["screening_mode"] == "actual-upload"
    assert response["demo_mode"] is None
    assert response["confidence"] is None
    assert response["description"] == FOOT_DESCRIPTIONS[expected_status]
    assert response["model"] == "opencv-region-screening"
    assert "not clinically validated" in response["disclaimer"].lower()
    assert isinstance(response["image_metrics"]["sharpness"], float)
    assert isinstance(response["image_metrics"]["localized_region_count"], float)


def test_localized_suspicious_region_includes_normalized_coordinates() -> None:
    result = analyze_foot_image(_foot_image_bytes("mild"))

    assert result["status"] == "MILD FINDING"
    assert len(result["regions"]) == 1
    region = result["regions"][0]
    assert region["label"] == "suspicious visual region"
    assert 0.0 <= region["x"] <= 1.0
    assert 0.0 <= region["y"] <= 1.0
    assert 0.0 < region["width"] <= 1.0
    assert 0.0 < region["height"] <= 1.0
    assert region["area_fraction"] < 0.07


def test_synthetic_drawing_without_photographic_detail_is_inconclusive() -> None:
    response = analyze_foot_image(_foot_image_bytes("synthetic_drawing"))

    assert response["status"] == "INCONCLUSIVE"
    assert "photographic detail" in response["reason"].lower()


@pytest.mark.parametrize(
    ("image", "reason_fragment"),
    [
        (_foot_image_bytes(blur_radius=12), "blurry"),
        (_foot_image_bytes(brightness=0.12), "dark"),
        (b"not-an-image", "cannot be decoded"),
        (np.full((100, 120, 3), 130, dtype=np.uint8), "resolution is too low"),
    ],
)
def test_unsuitable_images_are_inconclusive(
    image: bytes | np.ndarray, reason_fragment: str
) -> None:
    result = analyze_foot_image(image)

    assert result["status"] == "INCONCLUSIVE"
    assert result["prediction"] == "INCONCLUSIVE"
    assert result["confidence"] is None
    assert result["regions"] == []
    assert reason_fragment in result["reason"].lower()


def test_valid_upload_is_deterministic_without_model_or_remote_service() -> None:
    image = _foot_image_bytes("normal")

    first = predict_foot(image)
    second = predict_foot(image)

    assert first["status"] == second["status"] == "NORMAL"
    assert first["image_metrics"] == second["image_metrics"]


def test_assessment_requires_user_provided_features_and_preserves_no_answers() -> None:
    with pytest.raises(ValueError, match="Missing required assessment fields"):
        assess_diabetes({"HighBP": 0})

    payload = _assessment_payload()
    payload.update(
        {
            "PhysActivity": 3,
            "Fruits": 1,
            "Veggies": 2,
            "HvyAlcoholConsump": 0,
            "AnyHealthcare": 0,
            "NoDocbcCost": 0,
            "GenHlth": 2,
            "MentHlth": 0,
            "PhysHlth": 0,
            "Education": 5,
            "Income": 6,
        }
    )
    vector = _build_brfss_feature_vector(payload)[0]

    assert FEATURE_KEYS == [
        "HighBP", "HighChol", "CholCheck", "BMI", "Smoker", "Stroke",
        "HeartDiseaseorAttack", "PhysActivity", "Fruits", "Veggies",
        "HvyAlcoholConsump", "AnyHealthcare", "NoDocbcCost", "GenHlth",
        "MentHlth", "PhysHlth", "DiffWalk", "Sex", "Age", "Education",
        "Income",
    ]
    assert vector[2] == pytest.approx((0 - BRFSS_MEANS[2]) / BRFSS_STDS[2])
    assert vector[7] == pytest.approx((1 - BRFSS_MEANS[7]) / BRFSS_STDS[7])
    assert vector[8] == pytest.approx((0 - BRFSS_MEANS[8]) / BRFSS_STDS[8])
    assert vector[9] == pytest.approx((1 - BRFSS_MEANS[9]) / BRFSS_STDS[9])
    assert vector[11] == pytest.approx((0 - BRFSS_MEANS[11]) / BRFSS_STDS[11])


def test_assessment_rejects_fractional_categorical_values() -> None:
    with pytest.raises(ValueError, match="HighBP must be a whole-number category"):
        assess_diabetes(
            {**_assessment_payload(), "HighBP": 0.5},
            model=_FixedProbabilityModel([0.5, 0.5]),
        )


def _assessment_payload() -> dict[str, int | float]:
    return {
        "HighBP": 0,
        "HighChol": 0,
        "CholCheck": 0,
        "BMI": 24.7,
        "Smoker": 0,
        "Stroke": 0,
        "HeartDiseaseorAttack": 0,
        "Age": 5,
        "Sex": 0,
        "DiffWalk": 0,
    }


class _FixedProbabilityModel:
    classes_ = np.array([0, 1])

    def __init__(self, probabilities: list[float]):
        self.probabilities = probabilities
        self.features = None

    def predict_proba(self, features):
        self.features = np.asarray(features)
        return np.asarray([self.probabilities], dtype=float)

def test_assessment_uses_raw_model_probabilities_without_calibration_or_defaults() -> None:
    model = _FixedProbabilityModel([0.73, 0.27])
    response = assess_diabetes(_assessment_payload(), model=model)

    assert response["target"] == 0
    assert response["risk_percentage"] == 27.0
    assert response["class_probabilities"] == {
        "normal": 73.0,
        "borderline": None,
        "diabetes": None,
        "combined_prediabetes_diabetes": 27.0,
    }
    assert "confidence" not in response
    assert response["probability_source"] == "raw_xgboost_predict_proba"
    assert "not independently calibrated" in response[
        "probability_calibration"
    ].lower()
    assert "training scaler" in response["probability_calibration"]
    assert np.isnan(model.features[0, 7:17]).any()


def test_assessment_preserves_the_model_positive_class_without_diagnosing_diabetes() -> None:
    response = assess_diabetes(
        _assessment_payload(), model=_FixedProbabilityModel([0.42, 0.58])
    )

    assert response["target"] == 1
    assert response["risk_percentage"] == 58.0
    assert response["risk_level"] == "borderline"
    assert "combined" in response["prediction"].lower()
    assert "diagnosis" in response["explanation"].lower()


def test_binary_model_does_not_claim_separate_borderline_or_diabetes_probabilities() -> None:
    response = assess_diabetes(
        _assessment_payload(), model=_FixedProbabilityModel([0.5, 0.5])
    )

    assert response["class_probabilities"]["borderline"] is None
    assert response["class_probabilities"]["diabetes"] is None


def test_assessment_rejects_an_unavailable_model_instead_of_fabricating_a_score() -> None:
    with pytest.raises(RuntimeError, match="unavailable"):
        assess_diabetes(_assessment_payload())


def test_inconclusive_foot_does_not_change_assessment_score_or_status() -> None:
    response = predict_final(
        {"risk_percentage": 9.1, "prediction": "Normal"},
        {"status": "Normal", "prediction": "Healthy Fundus - No Retinopathy"},
        {"status": "INCONCLUSIVE", "prediction": "INCONCLUSIVE", "risk_percentage": 80.0},
    )

    assert response["overall_risk_percentage"] is None
    assert response["risk_level"] == "healthy"
    assert response["prediction_label"] == "Normal"
    assert response["assessment_score"] == 9.1
    assert response["retina_risk_percentage"] is None
    assert response["foot_risk_percentage"] is None
    assert "confidence" not in response


def test_inconclusive_foot_is_not_a_positive_finding() -> None:
    response = predict_final(
        {"risk_percentage": 9.1},
        {"prediction": "No Retinopathy"},
        {"status": "INCONCLUSIVE", "prediction": "INCONCLUSIVE"},
    )

    assert response["foot_risk_percentage"] is None
    assert response["overall_risk_percentage"] is None
    assert response["risk_level"] == "borderline"
    assert response["prediction_label"] == "Borderline / Further Assessment"


def test_normal_modules_produce_normal_overall_status() -> None:
    response = predict_final(
        {"risk_percentage": 9.1, "prediction": "Normal"},
        {"prediction": "Healthy Fundus - No Retinopathy"},
        {"status": "Normal", "prediction": "Normal"},
    )

    assert response["prediction_label"] == "Normal"
    assert response["risk_level"] == "healthy"
    assert response["overall_risk_percentage"] is None


def test_final_result_uses_model_class_and_forwards_only_available_confidence() -> None:
    probabilities = {
        "normal": 42.0,
        "borderline": None,
        "diabetes": None,
        "combined_prediabetes_diabetes": 58.0,
    }
    response = predict_final(
        {
            "target": 1,
            "risk_percentage": 58.0,
            "class_probabilities": probabilities,
            "prediction": "Combined prediabetes/diabetes indicator predicted",
            "explanation": "Binary model output.",
        },
        {"prediction": "Mild Retinopathy", "confidence": 92.5},
        {"status": "MILD FINDING", "prediction": "MILD FINDING"},
    )

    assert response["risk_level"] == "borderline"
    assert response["assessment_class_probabilities"] == probabilities
    assert response["assessment_explanation"] == "Binary model output."
    assert response["retina_confidence"] == 92.5
    assert response["foot_confidence"] is None
    assert response["overall_risk_percentage"] is None


def test_final_result_does_not_forward_invalid_module_confidence() -> None:
    response = predict_final(
        {"target": 0, "risk_percentage": 12.5, "prediction": "Normal"},
        {"prediction": "Healthy Fundus", "confidence": 140},
        {"status": "Normal", "confidence": -2},
    )

    assert response["retina_confidence"] is None
    assert response["foot_confidence"] is None


def test_ulcer_suspected_produces_further_assessment() -> None:
    response = predict_final(
        {"risk_percentage": 9.1, "prediction": "Normal"},
        {"prediction": "Healthy Fundus - No Retinopathy"},
        {"status": "ULCER SUSPECTED", "prediction": "ULCER SUSPECTED"},
    )

    assert response["prediction_label"] == "Borderline / Further Assessment"
    assert response["risk_level"] == "borderline"


def test_mild_foot_finding_remains_individual_and_does_not_change_overall() -> None:
    response = predict_final(
        {"risk_percentage": 5.0, "prediction": "Normal"},
        {"prediction": "Healthy Fundus - No Retinopathy"},
        {"status": "MILD FINDING", "prediction": "MILD FINDING"},
    )

    assert response["foot_result"] == "MILD FINDING"
    assert response["prediction_label"] == "Normal"
    assert response["risk_level"] == "healthy"


def test_severe_foot_finding_is_preserved_in_multimodal_result() -> None:
    response = predict_final(
        {"risk_percentage": 5.0, "prediction": "Normal"},
        {"prediction": "Healthy Fundus - No Retinopathy"},
        {"status": "SEVERE FINDING", "prediction": "SEVERE FINDING"},
    )

    assert response["foot_result"] == "SEVERE FINDING"
    assert response["prediction_label"] == "Borderline / Further Assessment"
    assert response["risk_level"] == "borderline"


def test_missing_assessment_score_is_not_replaced() -> None:
    with pytest.raises(ValueError, match="assessment score"):
        predict_final(
            {},
            {"prediction": "Healthy Fundus - No Retinopathy"},
            {"status": "Normal", "prediction": "Normal"},
        )
