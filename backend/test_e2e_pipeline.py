import asyncio
import os
import sys
from pathlib import Path

# Add project root to sys.path
root_dir = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root_dir))

from fastapi.testclient import TestClient
from backend.app import app

def test_full_pipeline():
    print("=" * 60)
    print("STARTING FULL END-TO-END FASTAPI PIPELINE TEST")
    print("=" * 60)

    # 1. Trigger app startup to load models into state
    app.state.model_registry.load_all()

    client = TestClient(app)

    # 2. Health check
    response = client.get("/health")
    assert response.status_code == 200
    print("✅ Health Check Passed:", response.json())

    # 3. Assessment Endpoint
    assessment_payload = {
        "HighBP": 1,
        "HighChol": 1,
        "BMI": 32.5,
        "Stroke": 0,
        "HeartDiseaseorAttack": 0,
        "Age": 8,
        "DiffWalk": 1,
        "FamilyHistory": 1,
        "FamilyMembersCount": 2,
        "StressLevel": 3,
        "JunkFood": 1,
        "SugaryDrinks": 1,
        "SittingHours": 4,
        "SleepDuration": 6,
        "PhysHlthRating": 2,
        "MentHlthRating": 2,
    }
    response = client.post("/predict/assessment", json=assessment_payload)
    assert response.status_code == 200
    assessment_res = response.json()
    assert assessment_res["success"] is True
    assert "risk_percentage" in assessment_res
    print("✅ Assessment Endpoint Passed:", assessment_res)

    # 4. Retina Endpoint with sample public image URL
    test_image_url = "https://raw.githubusercontent.com/tensorflow/tensorflow/master/tensorflow/core/example/example.proto"
    # Using a valid public image URL
    sample_image_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a9/Example.jpg/320px-Example.jpg"

    retina_payload = {"imageUrl": sample_image_url}
    response = client.post("/predict/retina", json=retina_payload)
    assert response.status_code == 200
    retina_res = response.json()
    assert retina_res["success"] is True
    assert "prediction" in retina_res
    assert "risk_percentage" in retina_res
    print("✅ Retina Endpoint Passed:", retina_res)

    # 5. Foot Endpoint
    foot_payload = {"imageUrl": sample_image_url}
    response = client.post("/predict/foot", json=foot_payload)
    assert response.status_code == 200
    foot_res = response.json()
    assert foot_res["success"] is True
    assert "prediction" in foot_res
    assert "risk_percentage" in foot_res
    print("✅ Foot Endpoint Passed:", foot_res)

    # 6. Final Prediction Endpoint
    final_payload = {
        "assessment": assessment_res,
        "retina": retina_res,
        "foot": foot_res,
        "retinaImage": sample_image_url,
        "footImage": sample_image_url,
    }
    response = client.post("/predict/final", json=final_payload)
    assert response.status_code == 200
    final_res = response.json()
    assert final_res["success"] is True
    assert "overall_risk_percentage" in final_res
    assert "risk_level" in final_res
    print("✅ Final Prediction Endpoint Passed:", final_res)

    print("=" * 60)
    print("🎉 ALL END-TO-END PIPELINE TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == "__main__":
    test_full_pipeline()
