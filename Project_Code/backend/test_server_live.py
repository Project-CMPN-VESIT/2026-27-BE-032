import os
import sys
import time
import subprocess
from pathlib import Path
import httpx

def main():
    print("=" * 70)
    print("TESTING BACKEND STARTUP FROM INSIDE 'backend/' DIRECTORY")
    print("=" * 70)

    backend_dir = Path(__file__).resolve().parent
    project_root = backend_dir.parent

    cmd = [sys.executable, "-m", "uvicorn", "app:app", "--host", "127.0.0.1", "--port", "8000"]
    print(f"Launching subprocess in: {backend_dir}")
    print(f"Command: {' '.join(cmd)}")

    proc = subprocess.Popen(
        cmd,
        cwd=str(backend_dir),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1
    )

    base_url = "http://127.0.0.1:8000"
    client = httpx.Client(base_url=base_url, timeout=30.0)

    print("Waiting for uvicorn server to start...")
    start_time = time.time()
    ready = False

    while time.time() - start_time < 90:
        if proc.poll() is not None:
            # Subprocess exited prematurely!
            out, _ = proc.communicate()
            print("ERROR: uvicorn process exited prematurely!")
            print("Subprocess Output:")
            print(out)
            sys.exit(1)

        try:
            r = client.get("/health")
            if r.status_code == 200:
                ready = True
                print(f"✅ Uvicorn server started successfully in {int(time.time() - start_time)}s!")
                break
        except Exception:
            time.sleep(1.0)

    if not ready:
        proc.terminate()
        out, _ = proc.communicate(timeout=5)
        print("ERROR: Timeout waiting for server")
        print(out)
        sys.exit(1)

    print("\n--- Running Endpoint Verifications ---")
    results = []

    # 1. /health
    r = client.get("/health")
    passed = r.status_code == 200 and r.json().get("status") == "ok"
    results.append(("/health", "Health check", "PASS" if passed else "FAIL", r.status_code, str(r.json())))
    print(f"[{results[-1][2]}] /health -> HTTP {r.status_code}: {r.json()}")

    # 2. /docs (Swagger)
    r = client.get("/docs")
    passed = r.status_code == 200 and "swagger" in r.text.lower()
    results.append(("/docs", "Swagger UI", "PASS" if passed else "FAIL", r.status_code, "Swagger UI loaded"))
    print(f"[{results[-1][2]}] /docs -> HTTP {r.status_code}: Swagger Documentation loaded successfully")

    # 3. /predict/assessment
    payload_assessment = {
        "HighBP": 1, "HighChol": 1, "CholCheck": 1, "BMI": 32.5,
        "Smoker": 0, "Stroke": 0, "HeartDiseaseorAttack": 0, "Age": 8,
        "Sex": 1, "Education": 5, "Income": 6, "HvyAlcoholConsump": 0,
        "AnyHealthcare": 1, "NoDocbcCost": 0, "DiffWalk": 1,
        "FamilyHistory": 1, "FamilyMembersCount": 2, "StressLevel": 3,
        "JunkFood": 1, "SugaryDrinks": 1, "SittingHours": 4,
        "SleepDuration": 2, "PhysHlthRating": 2, "MentHlthRating": 2,
    }
    r = client.post("/predict/assessment", json=payload_assessment)
    data = r.json()
    passed = r.status_code == 200 and data.get("success") is True and "risk_percentage" in data
    results.append(("/predict/assessment", "XGBoost Assessment", "PASS" if passed else "FAIL", r.status_code, f"risk={data.get('risk_percentage')}%"))
    print(f"[{results[-1][2]}] /predict/assessment -> HTTP {r.status_code}: risk={data.get('risk_percentage')}%, label='{data.get('prediction')}'")

    # 4. /predict/retina (Path)
    test_retina_path = project_root / "test_retina.jpg"
    r = client.post("/predict/retina", json={"imageUrl": str(test_retina_path)})
    data = r.json()
    passed = r.status_code == 200 and data.get("success") is True
    retina_data = data
    results.append(("/predict/retina (Path)", "Retina ViT Model", "PASS" if passed else "FAIL", r.status_code, f"pred='{data.get('prediction')}'"))
    print(f"[{results[-1][2]}] /predict/retina (Path) -> HTTP {r.status_code}: prediction='{data.get('prediction')}', risk={data.get('risk_percentage')}%")

    # 5. /predict/retina (Multipart)
    with open(test_retina_path, "rb") as f:
        r = client.post("/predict/retina", files={"file": ("retina.jpg", f, "image/jpeg")})
    data = r.json()
    passed = r.status_code == 200 and data.get("success") is True
    results.append(("/predict/retina (Multipart)", "Retina Multipart Upload", "PASS" if passed else "FAIL", r.status_code, f"pred='{data.get('prediction')}'"))
    print(f"[{results[-1][2]}] /predict/retina (Multipart) -> HTTP {r.status_code}: prediction='{data.get('prediction')}'")

    # 6. /predict/foot (Path)
    test_foot_path = project_root / "test_foot.jpg"
    r = client.post("/predict/foot", json={"imageUrl": str(test_foot_path)})
    data = r.json()
    passed = r.status_code == 200 and data.get("success") is True
    foot_data = data
    results.append(("/predict/foot (Path)", "Foot Model / Screening", "PASS" if passed else "FAIL", r.status_code, f"pred='{data.get('prediction')}'"))
    print(f"[{results[-1][2]}] /predict/foot (Path) -> HTTP {r.status_code}: prediction='{data.get('prediction')}', severity='{data.get('severity')}'")

    # 7. /predict/foot (Multipart)
    with open(test_foot_path, "rb") as f:
        r = client.post("/predict/foot", files={"file": ("foot.jpg", f, "image/jpeg")})
    data = r.json()
    passed = r.status_code == 200 and data.get("success") is True
    results.append(("/predict/foot (Multipart)", "Foot Multipart Upload", "PASS" if passed else "FAIL", r.status_code, f"pred='{data.get('prediction')}'"))
    print(f"[{results[-1][2]}] /predict/foot (Multipart) -> HTTP {r.status_code}: prediction='{data.get('prediction')}'")

    # 8. /predict/final
    final_payload = {
        "assessment": payload_assessment,
        "retina": retina_data,
        "foot": foot_data,
    }
    final_payload["assessment"]["risk_percentage"] = 72.5
    r = client.post("/predict/final", json=final_payload)
    data = r.json()
    passed = r.status_code == 200 and data.get("success") is True
    results.append(("/predict/final", "Multi-modal Aggregation", "PASS" if passed else "FAIL", r.status_code, f"overall={data.get('overall_risk_percentage')}%"))
    print(f"[{results[-1][2]}] /predict/final -> HTTP {r.status_code}: overall_risk={data.get('overall_risk_percentage')}%, level='{data.get('risk_level')}'")

    # Clean shutdown
    print("\nShutting down uvicorn server...")
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()

    print("\n" + "=" * 70)
    print("FINAL TEST RESULTS TABLE:")
    print("=" * 70)
    print(f"| {'Endpoint':<28} | {'Description':<30} | {'Status':<6} | {'HTTP Code':<9} |")
    print(f"|{'-'*30}|{'-'*32}|{'-'*8}|{'-'*11}|")
    for endpoint, desc, status, code, _ in results:
        print(f"| {endpoint:<28} | {desc:<30} | {status:<6} | HTTP {code:<5} |")
    print("=" * 70)

    if all(r[2] == "PASS" for r in results):
        print("🎉 ALL 8 TESTS PASSED SUCCESSFULLY!")
    else:
        print("❌ SOME TESTS FAILED!")
        sys.exit(1)

if __name__ == "__main__":
    main()
