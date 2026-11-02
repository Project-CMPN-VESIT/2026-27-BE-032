import os
import sys
from pathlib import Path

# Ensure stdout supports UTF-8 on Windows
if sys.platform == "win32" and sys.stdout.encoding.lower() != "utf-8":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Add project root to sys.path
root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

from fastapi.testclient import TestClient
from backend.app import app
from backend.test_inference import _foot_image_bytes
from backend.services.prediction_service import _build_brfss_feature_vector


def test_full_pipeline():
    print("=" * 70, flush=True)
    print("STARTING FULL END-TO-END FASTAPI PIPELINE TEST", flush=True)
    print("=" * 70, flush=True)

    with TestClient(app) as client:
        # 1. Health check
        print("\n[TEST 1] Testing /health ...", flush=True)
        response = client.get("/health")
        assert response.status_code == 200, f"Health check failed: {response.text}"
        print("PASS: Health Check ->", response.json(), flush=True)

        # 2. Swagger / Docs
        print("\n[TEST 2] Testing /docs (Swagger documentation) ...", flush=True)
        docs_resp = client.get("/docs")
        assert docs_resp.status_code == 200, f"/docs failed: {docs_resp.status_code}"
        assert "swagger" in docs_resp.text.lower(), "Swagger UI not found in /docs"
        print("PASS: Swagger Documentation at /docs is accessible (HTTP 200)", flush=True)

        # 3. Assessment Endpoint
        print("\n[TEST 3] Testing /predict/assessment (XGBoost probabilities) ...", flush=True)
        assessment_payload = {
            "HighBP": 1,
            "HighChol": 1,
            "CholCheck": 1,
            "BMI": 32.5,
            "Smoker": 0,
            "Stroke": 0,
            "HeartDiseaseorAttack": 0,
            "Age": 8,
            "Sex": 1,
            "Education": 5,
            "Income": 6,
            "HvyAlcoholConsump": 0,
            "AnyHealthcare": 1,
            "NoDocbcCost": 0,
            "DiffWalk": 1,
            "FamilyHistory": 1,
            "FamilyMembersCount": 2,
            "StressLevel": 3,
            "JunkFood": 1,
            "SugaryDrinks": 1,
            "SittingHours": 4,
            "SleepDuration": 2,
            "PhysHlthRating": 2,
            "MentHlthRating": 2,
        }
        response = client.post("/predict/assessment", json=assessment_payload)
        assert response.status_code == 200, f"Assessment failed: {response.text}"
        assessment_res = response.json()
        assert assessment_res.get("success") is True
        assert "risk_percentage" in assessment_res
        assert assessment_res["probability_source"] == "raw_xgboost_predict_proba"
        assert assessment_res["class_probabilities"]["borderline"] is None
        assert assessment_res["class_probabilities"]["diabetes"] is None
        assert assessment_res["class_probabilities"][
            "combined_prediabetes_diabetes"
        ] == assessment_res["risk_percentage"]
        assert "confidence" not in assessment_res
        print(f"PASS: Assessment -> risk: {assessment_res['risk_percentage']}%, label: '{assessment_res.get('prediction')}'", flush=True)

        flutter_form_payload = {
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
            "PhysActivity": 0,
            "SleepDuration": 1,
        }
        form_response = client.post(
            "/predict/assessment", json=flutter_form_payload
        )
        assert form_response.status_code == 200, form_response.text
        assert form_response.json()["success"] is True
        assert form_response.json()["probability_source"] == "raw_xgboost_predict_proba"

        low_risk_answers = {
            "HighBP": 0,
            "HighChol": 0,
            "CholCheck": 1,
            "BMI": 22.0,
            "Smoker": 0,
            "Stroke": 0,
            "HeartDiseaseorAttack": 0,
            "Age": 1,
            "Sex": 0,
            "DiffWalk": 0,
            "PhysActivity": 0,
            "Fruits": 2,
            "Veggies": 2,
        }
        high_risk_answers = {
            "HighBP": 1,
            "HighChol": 1,
            "CholCheck": 1,
            "BMI": 40.0,
            "Smoker": 1,
            "Stroke": 1,
            "HeartDiseaseorAttack": 1,
            "Age": 13,
            "Sex": 1,
            "DiffWalk": 1,
            "PhysActivity": 0,
            "Fruits": 0,
            "Veggies": 0,
        }
        low_response = client.post(
            "/predict/assessment", json=low_risk_answers
        )
        high_response = client.post(
            "/predict/assessment", json=high_risk_answers
        )
        assert low_response.status_code == 200, low_response.text
        assert high_response.status_code == 200, high_response.text
        low_result = low_response.json()
        high_result = high_response.json()
        assessment_model = app.state.model_registry.assessment_model
        positive_class_index = list(assessment_model.classes_).index(1)
        for answers, result in (
            (low_risk_answers, low_result),
            (high_risk_answers, high_result),
        ):
            model_probability = assessment_model.predict_proba(
                _build_brfss_feature_vector(answers)
            )[0][positive_class_index]
            expected_percentage = round(float(model_probability) * 100.0, 2)
            assert result["risk_percentage"] == expected_percentage
            assert (
                result["class_probabilities"][
                    "combined_prediabetes_diabetes"
                ]
                == expected_percentage
            )
        assert high_result["risk_percentage"] > low_result["risk_percentage"]

        missing_assessment = client.post(
            "/predict/assessment", json={"HighBP": 0}
        )
        assert missing_assessment.status_code == 422
        assert "Missing required assessment fields" in missing_assessment.json()["detail"]

        # 4. Retina Endpoint with local file path
        print("\n[TEST 4] Testing /predict/retina with local image path ...", flush=True)
        test_retina_path = root_dir / "test_retina.jpg"
        response = client.post("/predict/retina", json={"imageUrl": str(test_retina_path)})
        assert response.status_code == 200, f"Retina JSON failed: {response.text}"
        retina_res = response.json()
        assert retina_res.get("success") is True
        assert "prediction" in retina_res
        assert "risk_percentage" not in retina_res
        assert isinstance(retina_res.get("confidence"), (int, float))
        print(f"PASS: Retina (Path) -> prediction: '{retina_res['prediction']}', model confidence: {retina_res['confidence']}%", flush=True)

        # 5. Retina Endpoint with Multipart file upload (as sent by Flutter)
        print("\n[TEST 5] Testing /predict/retina with Multipart/form-data upload ...", flush=True)
        with open(test_retina_path, "rb") as f:
            response = client.post(
                "/predict/retina",
                files={"file": ("retina.jpg", f, "image/jpeg")},
            )
        assert response.status_code == 200, f"Retina multipart failed: {response.text}"
        retina_multipart_res = response.json()
        assert retina_multipart_res.get("success") is True
        assert retina_multipart_res["prediction"] == retina_res["prediction"]
        print(f"PASS: Retina (Multipart) -> prediction: '{retina_multipart_res['prediction']}'", flush=True)

        # 6. Foot Endpoint with real multipart image bytes
        print("\n[TEST 6] Testing /predict/foot with OpenCV image analysis ...", flush=True)
        foot_res = None
        for feature, expected in (
            ("normal", "NORMAL"),
            ("mild", "MILD FINDING"),
            ("severe", "SEVERE FINDING"),
        ):
            response = client.post(
                "/predict/foot",
                files={
                    "file": (
                        f"{feature}.jpg",
                        _foot_image_bytes(feature),
                        "image/jpeg",
                    )
                },
            )
            assert response.status_code == 200, response.text
            actual = response.json()
            assert actual["success"] is True
            assert actual["status"] == expected
            assert actual["model"] == "opencv-region-screening"
            assert actual["screening_mode"] == "actual-upload"
            assert actual["demo_mode"] is None
            assert actual["confidence"] is None
            assert isinstance(actual["image_metrics"], dict)
            assert "risk_percentage" not in actual
            if expected == "NORMAL":
                foot_res = actual
            print(f"PASS: multipart {feature} -> {actual['status']}", flush=True)

        assert foot_res is not None
        nonphotographic_response = client.post(
            "/predict/foot",
            files={
                "file": (
                    "synthetic-drawing.jpg",
                    _foot_image_bytes("synthetic_drawing"),
                    "image/jpeg",
                )
            },
        )
        assert nonphotographic_response.status_code == 200
        assert nonphotographic_response.json()["status"] == "INCONCLUSIVE"
        invalid_foot_response = client.post(
            "/predict/foot",
            files={"file": ("invalid.jpg", b"not-an-image", "image/jpeg")},
        )
        assert invalid_foot_response.status_code == 200
        assert invalid_foot_response.json()["status"] == "INCONCLUSIVE"
        assert "cannot be decoded" in invalid_foot_response.json()["reason"]
        remote_foot_response = client.post(
            "/predict/foot",
            json={"imageUrl": "https://example.invalid/foot.jpg"},
        )
        assert remote_foot_response.status_code == 422
        assert "multipart/form-data" in remote_foot_response.json()["detail"]

        # 7. Final Prediction Endpoint (multi-modal fusion)
        print("\n[TEST 8] Testing /predict/final (Multi-modal Aggregator) ...", flush=True)
        final_payload = {
            "assessment": assessment_res,
            "retina": retina_res,
            "foot": foot_res,
        }
        response = client.post("/predict/final", json=final_payload)
        assert response.status_code == 200, f"Final endpoint failed: {response.text}"
        final_res = response.json()
        assert final_res.get("success") is True
        assert final_res.get("overall_risk_percentage") is None
        assert final_res["assessment_score"] == assessment_res["risk_percentage"]
        assert final_res["retina_result"] == retina_res["prediction"]
        assert final_res["foot_result"] == foot_res["status"]
        assert (
            final_res["assessment_class_probabilities"]
            == assessment_res["class_probabilities"]
        )
        assert final_res["retina_confidence"] == retina_res["confidence"]
        assert final_res["foot_confidence"] is None
        assert "risk_level" in final_res
        assert "care_plan" in final_res
        print(f"PASS: Final Screening -> assessment score: {final_res['assessment_score']}%, level: '{final_res['risk_level']}', label: '{final_res['prediction_label']}'", flush=True)

    print("\n" + "=" * 70, flush=True)
    print("ALL ENDPOINT TESTS PASSED!", flush=True)
    print("=" * 70, flush=True)


if __name__ == "__main__":
    test_full_pipeline()
