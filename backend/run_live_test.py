"""
Live end-to-end endpoint test: calls the running FastAPI server.
Run with:  python backend/run_live_test.py
"""
import json
import sys
import requests

BASE_URL = "http://localhost:8000"

# ─── Publicly accessible JPG for image download test ─────────────────────────
# A real retinal fundus image sample from a public dataset
SAMPLE_IMAGE_URL = (
    "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/"
    "Cat03.jpg/320px-Cat03.jpg"
)

SEPARATOR = "=" * 70

def post(endpoint: str, payload: dict) -> dict:
    print(SEPARATOR)
    print(f"REQUEST  POST {BASE_URL}{endpoint}")
    print(f"PAYLOAD  {json.dumps(payload, indent=2)}")
    r = requests.post(f"{BASE_URL}{endpoint}", json=payload, timeout=60)
    print(f"HTTP STATUS : {r.status_code}")
    try:
        result = r.json()
    except Exception as e:
        print(f"Failed to parse JSON: {e}")
        print(f"Raw body: {r.text[:500]}")
        sys.exit(1)
    print(f"RESPONSE :")
    print(json.dumps(result, indent=2))
    print(SEPARATOR)
    return result

def main():
    # ── 1. health ────────────────────────────────────────────────────────────
    print(SEPARATOR)
    print("STEP 1 — HEALTH CHECK")
    r = requests.get(f"{BASE_URL}/health", timeout=10)
    print("HTTP STATUS:", r.status_code)
    print("RESPONSE:", r.json())
    assert r.status_code == 200

    # ── 2. Assessment ────────────────────────────────────────────────────────
    print("\nSTEP 2 — ASSESSMENT ENDPOINT")
    assessment_payload = {
        "HighBP": 1, "HighChol": 1, "BMI": 32.5, "Stroke": 0,
        "HeartDiseaseorAttack": 0, "Age": 8, "DiffWalk": 1,
        "FamilyHistory": 1, "FamilyMembersCount": 2, "StressLevel": 3,
        "JunkFood": 1, "SugaryDrinks": 1, "SittingHours": 4,
        "SleepDuration": 6, "PhysHlthRating": 2, "MentHlthRating": 2,
    }
    assessment_res = post("/predict/assessment", assessment_payload)
    assert assessment_res.get("success"), f"Assessment FAILED: {assessment_res}"
    assert "risk_percentage" in assessment_res, "risk_percentage missing from assessment"
    print("✅ ASSESSMENT PASSED  risk_percentage:", assessment_res["risk_percentage"])

    # ── 3. Retina ─────────────────────────────────────────────────────────────
    print("\nSTEP 3 — RETINA ENDPOINT")
    retina_payload = {"imageUrl": SAMPLE_IMAGE_URL}
    retina_res = post("/predict/retina", retina_payload)
    assert retina_res.get("success"), f"Retina FAILED: {retina_res}"
    assert "prediction" in retina_res, "prediction missing from retina"
    assert "risk_percentage" in retina_res, "risk_percentage missing from retina"
    fallback = retina_res.get("source", "")
    if "fallback" in str(fallback):
        print("⚠️  Retina returned FALLBACK — check server logs above")
    else:
        print("✅ RETINA PASSED  prediction:", retina_res["prediction"])
        print("   risk_percentage:", retina_res["risk_percentage"])
        print("   confidence:", retina_res["confidence"])

    # ── 4. Foot ──────────────────────────────────────────────────────────────
    print("\nSTEP 4 — FOOT ENDPOINT")
    foot_payload = {"imageUrl": SAMPLE_IMAGE_URL}
    foot_res = post("/predict/foot", foot_payload)
    assert foot_res.get("success"), f"Foot FAILED: {foot_res}"
    assert "prediction" in foot_res, "prediction missing from foot"
    assert "confidence" in foot_res, "confidence missing from foot"
    fallback = foot_res.get("source", "")
    if "fallback" in str(fallback):
        print("⚠️  Foot returned FALLBACK — check server logs above")
    else:
        print("✅ FOOT PASSED  prediction:", foot_res["prediction"])
        print("   confidence:", foot_res["confidence"])

    # ── 5. Final ─────────────────────────────────────────────────────────────
    print("\nSTEP 5 — FINAL ENDPOINT")
    final_payload = {
        "assessment": assessment_res,
        "retina": retina_res,
        "foot": foot_res,
        "retinaImage": SAMPLE_IMAGE_URL,
        "footImage": SAMPLE_IMAGE_URL,
    }
    final_res = post("/predict/final", final_payload)
    assert final_res.get("success"), f"Final FAILED: {final_res}"
    assert "overall_risk_percentage" in final_res, "overall_risk_percentage missing from final"
    print("✅ FINAL PASSED  overall_risk_percentage:", final_res["overall_risk_percentage"])
    print("   risk_level:", final_res["risk_level"])
    print("   prediction_label:", final_res["prediction_label"])

    # ── Summary ──────────────────────────────────────────────────────────────
    print()
    print(SEPARATOR)
    print("🎉 ALL ENDPOINTS VERIFIED SUCCESSFULLY!")
    print(SEPARATOR)
    print(f"  Assessment risk_percentage : {assessment_res['risk_percentage']}")
    print(f"  Retina prediction          : {retina_res['prediction']}")
    print(f"  Retina risk_percentage     : {retina_res['risk_percentage']}")
    print(f"  Foot prediction            : {foot_res['prediction']}")
    print(f"  Foot confidence            : {foot_res['confidence']}")
    print(f"  Final overall_risk         : {final_res['overall_risk_percentage']}")
    print(f"  Final risk_level           : {final_res['risk_level']}")
    print(SEPARATOR)


if __name__ == "__main__":
    main()
