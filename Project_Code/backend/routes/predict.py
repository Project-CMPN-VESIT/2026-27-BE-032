from __future__ import annotations

from datetime import datetime
import logging
import os
import traceback
from typing import Any, Dict, Optional

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field

from backend.services.prediction_service import (
    assess_diabetes,
    predict_foot,
    predict_final,
    predict_retina,
)

router = APIRouter(tags=["prediction"])
logger = logging.getLogger(__name__)


class AssessmentPayload(BaseModel):
    HighBP: Optional[int] = 0
    HighChol: Optional[int] = 0
    BMI: Optional[float] = 24.0
    Stroke: Optional[int] = 0
    HeartDiseaseorAttack: Optional[int] = 0
    Age: Optional[int] = 5
    DiffWalk: Optional[int] = 0
    FamilyHistory: Optional[int] = 0
    FamilyMembersCount: Optional[int] = 0
    StressLevel: Optional[int] = 1
    JunkFood: Optional[int] = 0
    SugaryDrinks: Optional[int] = 0
    SittingHours: Optional[int] = 1
    SleepDuration: Optional[int] = 3
    PhysHlthRating: Optional[int] = 1
    MentHlthRating: Optional[int] = 1


class ImagePredictionPayload(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    imageUrl: Optional[str] = Field(default=None, alias="imageUrl")
    image_url: Optional[str] = None
    image_path: Optional[str] = None


class FinalPredictionPayload(BaseModel):
    assessment: Optional[Dict[str, Any]] = None
    retina: Optional[Dict[str, Any]] = None
    foot: Optional[Dict[str, Any]] = None
    retinaImage: Optional[str] = None
    footImage: Optional[str] = None
    retina_result: Optional[Dict[str, Any]] = None
    foot_result: Optional[Dict[str, Any]] = None


@router.get("/health")
async def health() -> Dict[str, str]:
    return {"status": "ok", "service": "diabeticai"}


@router.post("/predict/assessment")
async def predict_assessment_endpoint(request: Request) -> Dict[str, Any]:
    timestamp = datetime.now().isoformat()
    content_type = request.headers.get("content-type", "")
    print("=" * 60)
    print(f"[ENDPOINT] ENDPOINT HIT: /predict/assessment | Time: {timestamp} | Method: {request.method} | Content-Type: {content_type}")
    print(f"   Headers: {dict(request.headers)}")
    try:
        payload = await request.json()
        print("ASSESSMENT PAYLOAD:", payload)
        result = assess_diabetes(payload, model=request.app.state.model_registry.assessment_model)
        print("ASSESSMENT RESULT:", result)
        print("=" * 60)
        return {"success": True, **result}
    except Exception as exc:
        print("[ERROR] ASSESSMENT ENDPOINT ERROR:", exc)
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Assessment prediction failed: {exc}") from exc


@router.post("/predict/retina")
async def predict_retina_endpoint(request: Request) -> Dict[str, Any]:
    timestamp = datetime.now().isoformat()
    content_type = request.headers.get("content-type", "")
    print("=" * 60)
    print(f"[ENDPOINT] ENDPOINT HIT: /predict/retina | Time: {timestamp} | Method: {request.method} | Content-Type: {content_type}")
    print(f"   Headers: {dict(request.headers)}")
    try:
        image_input = None

        if "multipart/form-data" in content_type:
            print("RETINA REQUEST TYPE: multipart/form-data")
            form = await request.form()
            file_obj = form.get("file") or form.get("image")
            if file_obj and hasattr(file_obj, "read"):
                image_input = await file_obj.read()
                print(f"RETINA MULTIPART UPLOAD: received {len(image_input)} bytes")
            else:
                image_input = form.get("imageUrl") or form.get("image_url")
        else:
            payload = await request.json()
            print("RETINA PAYLOAD:", payload)
            print("RETINA JSON PAYLOAD:", payload)
            image_input = (
                payload.get("imageUrl")
                or payload.get("image_url")
                or payload.get("url")
            )

        print("RETINA IMAGE INPUT TYPE:", type(image_input))

        result = predict_retina(
            image_url=image_input,
            model=request.app.state.model_registry.retina_model,
        )

        print("RETINA RESULT:", result)
        print("=" * 60)

        return {"success": True, **result}

    except Exception as exc:
        print("[ERROR] RETINA ENDPOINT ERROR:", exc)
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Retina prediction failed: {exc}",
        ) from exc


@router.post("/predict/foot")
async def predict_foot_endpoint(request: Request) -> Dict[str, Any]:
    timestamp = datetime.now().isoformat()
    content_type = request.headers.get("content-type", "")
    print("=" * 60)
    print(f"[ENDPOINT] ENDPOINT HIT: /predict/foot | Time: {timestamp} | Method: {request.method} | Content-Type: {content_type}")
    print(f"   Headers: {dict(request.headers)}")
    try:
        image_input = None
        local_path = "N/A"
        storage_url = "N/A"
        file_size = "N/A"
        md5_hash = "N/A"
        multipart_bytes_len = "N/A"

        if "multipart/form-data" in content_type:
            print("FOOT REQUEST TYPE: multipart/form-data")
            form = await request.form()
            file_obj = form.get("file") or form.get("image")
            if file_obj and hasattr(file_obj, "read"):
                image_input = await file_obj.read()
                try:
                    with open("uploaded_debug.jpg", "wb") as f_out:
                        f_out.write(image_input)
                    print("[ROUTE] [OK] Saved uploaded multipart image to uploaded_debug.jpg")
                except Exception as save_err:
                    print(f"[ROUTE] [WARN] Could not save uploaded_debug.jpg: {save_err}")
                multipart_bytes_len = f"{len(image_input)} bytes"
                file_size = f"{len(image_input)} bytes"
                import hashlib
                md5_hash = hashlib.md5(image_input).hexdigest()
                local_path = getattr(file_obj, "filename", "uploaded_multipart_file")
            else:
                image_input = form.get("imageUrl") or form.get("image_url")
                storage_url = str(image_input)
        else:
            payload = await request.json()
            print("FOOT PAYLOAD:", payload)
            print("FOOT JSON PAYLOAD:", payload)
            image_input = (
                payload.get("imageUrl")
                or payload.get("image_url")
                or payload.get("url")
            )
            if isinstance(image_input, str):
                if image_input.startswith(("http://", "https://")):
                    storage_url = image_input
                else:
                    clean_path = image_input.replace("file://", "")
                    local_path = clean_path
                    if os.path.exists(clean_path):
                        with open(clean_path, "rb") as f:
                            b = f.read()
                            file_size = f"{len(b)} bytes"
                            import hashlib
                            md5_hash = hashlib.md5(b).hexdigest()

        print("==================================================")
        print("BACKEND PREDICT FOOT CALL LOGS:")
        print(f"  - Local Image Path    : {local_path}")
        print(f"  - Storage URL         : {storage_url}")
        print(f"  - File Size           : {file_size}")
        print(f"  - MD5 Hash            : {md5_hash}")
        print(f"  - Multipart Bytes Len : {multipart_bytes_len}")
        print("==================================================")

        result = predict_foot(
            image_url=image_input,
            model=request.app.state.model_registry.foot_model,
        )

        print("FOOT RESULT:", result)
        print("=" * 60)

        return {"success": True, **result}

    except Exception as exc:
        print("[ROUTE] [ERROR] FOOT ENDPOINT ERROR:", exc)
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Foot prediction failed: {exc}",
        ) from exc


@router.post("/predict/final")
async def predict_final_endpoint(request: Request) -> Dict[str, Any]:
    timestamp = datetime.now().isoformat()
    content_type = request.headers.get("content-type", "")
    print("=" * 60)
    print(f"[ENDPOINT] ENDPOINT HIT: /predict/final | Time: {timestamp} | Method: {request.method} | Content-Type: {content_type}")
    print(f"   Headers: {dict(request.headers)}")
    try:
        payload = await request.json()
        print("FINAL PREDICTION PAYLOAD:", payload)
        assessment_result = payload.get("assessment")
        retina_result = payload.get("retina") or payload.get("retina_result")
        foot_result = payload.get("foot") or payload.get("foot_result")
        retina_url = payload.get("retinaImage") or (retina_result.get("imageUrl") if isinstance(retina_result, dict) else None)
        foot_url = payload.get("footImage") or (foot_result.get("imageUrl") if isinstance(foot_result, dict) else None)

        if not isinstance(assessment_result, dict) or not assessment_result.get("risk_percentage"):
            raise HTTPException(status_code=422, detail="Completed assessment result is required")
        if not isinstance(retina_result, dict) or not retina_result.get("prediction"):
            raise HTTPException(status_code=422, detail="Completed retina result is required")
        if not isinstance(foot_result, dict) or not foot_result.get("prediction"):
            raise HTTPException(status_code=422, detail="Completed foot result is required")

        result = predict_final(assessment_result, retina_result, foot_result)
        print("FINAL RESULT:", result)
        print("=" * 60)

        logger.info(
            "Final aggregation assessment=%s retina=%s foot=%s overall=%s",
            assessment_result,
            retina_result,
            foot_result,
            result["overall_risk_percentage"],
        )
        return {"success": True, **result}
    except HTTPException:
        raise
    except Exception as exc:
        print("[ERROR] FINAL ENDPOINT ERROR:")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Final prediction failed: {exc}") from exc


@router.post("/predict/diabetes")
async def predict_diabetes_alias(request: Request, payload: Dict[str, Any]) -> Dict[str, Any]:
    return await predict_assessment_endpoint(request, payload)


@router.post("/predict/foot-ulcer")
async def predict_foot_ulcer_alias(request: Request, payload: Dict[str, Any]) -> Dict[str, Any]:
    return await predict_foot_endpoint(request, payload)


@router.post("/predict/multi-modal")
async def predict_multi_modal_alias(request: Request, payload: Dict[str, Any]) -> Dict[str, Any]:
    return await predict_final_endpoint(request, payload)
