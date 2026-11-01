from __future__ import annotations

import os
import sys
import numpy as np

from pathlib import Path

# Ensure backend module can be imported from any location
current_file = Path(__file__).resolve()
for candidate in [current_file.parent.parent, current_file.parent.parent.parent]:
    if candidate.exists() and str(candidate) not in sys.path:
        sys.path.insert(0, str(candidate))
    if (candidate / "Project_Code").exists() and str(candidate / "Project_Code") not in sys.path:
        sys.path.insert(0, str(candidate / "Project_Code"))

from backend.services.prediction_service import predict_retina, predict_foot


class DummyKerasModel:
    def __init__(self, probabilities):
        self._probabilities = np.array([probabilities], dtype=np.float32)

    def predict(self, x, verbose=0):
        return self._probabilities


def test_model_none_fallback():
    print("--- Test 1: Model is None Fallback ---")
    ret = predict_retina("https://example.com/test.jpg", model=None)
    assert ret["prediction"] == "Healthy Fundus - No Retinopathy"
    assert ret["risk_percentage"] == 8.0
    print("PASSED: Retina Model=None Fallback Passed!")

    foot = predict_foot("https://example.com/test.jpg", model=None)
    assert foot["prediction"] in ["Grade 0 - No Lesion Detected", "No Lesion Detected"]
    print("PASSED: Foot Model=None Fallback Passed!")


def test_image_load_failure_fallback():
    print("\n--- Test 2: Image Load Failure Fallback ---")
    dummy_model = DummyKerasModel([0.9, 0.1])
    ret = predict_retina("invalid_image_path_or_url.jpg", model=dummy_model)
    assert ret["prediction"] == "Healthy Fundus - No Retinopathy"
    assert ret["risk_percentage"] == 8.0
    print("PASSED: Retina Load Failure Fallback Passed!")

    foot = predict_foot("invalid_image_path_or_url.jpg", model=dummy_model)
    assert foot["prediction"] in ["Grade 0 - No Lesion Detected", "No Lesion Detected"]
    print("PASSED: Foot Load Failure Fallback Passed!")


def test_real_model_inference():
    print("\n--- Test 3: Real Model Inference with Mock Model & Synthetic Image ---")
    from PIL import Image

    test_img_path = os.path.join(os.path.dirname(__file__), "test_synthetic.jpg")
    img = Image.new("RGB", (224, 224), color=(200, 100, 50))
    img.save(test_img_path)

    try:
        # Retina class 2 (Moderate Retinopathy)
        retina_model = DummyKerasModel([0.05, 0.10, 0.70, 0.10, 0.05])
        print("Running predict_retina with model...")
        ret = predict_retina(test_img_path, model=retina_model)
        print("Result:", ret)
        assert ret["prediction"] == "Moderate Non-Proliferative Retinopathy"
        assert ret["risk_percentage"] == 60.0
        assert ret["risk_level"] == "diabetic"
        print("PASSED: Retina Real Model Inference Passed!")

        # Foot class 1 (Grade 1 Superficial Foot Ulcer)
        foot_model = DummyKerasModel([0.1, 0.8, 0.05, 0.05])
        print("\nRunning predict_foot with model...")
        foot = predict_foot(test_img_path, model=foot_model)
        print("Result:", foot)
        assert "prediction" in foot
        assert "visible_findings" in foot
        if "ml_research_debug" in foot and "ml_label" in foot["ml_research_debug"]:
            assert foot["ml_research_debug"]["ml_label"] == "Grade 1 - Superficial Foot Ulcer Detected"
        print("PASSED: Foot Real Model Inference Passed!")

    finally:
        if os.path.exists(test_img_path):
            os.remove(test_img_path)


if __name__ == "__main__":
    import traceback

    for test_fn in [test_model_none_fallback, test_image_load_failure_fallback, test_real_model_inference]:
        try:
            test_fn()
        except Exception as e:
            print(f"\nFAIL in {test_fn.__name__}: {e}")
            traceback.print_exc()
            sys.exit(1)

    print("\nALL INFERENCE TESTS PASSED SUCCESSFULLY!")
