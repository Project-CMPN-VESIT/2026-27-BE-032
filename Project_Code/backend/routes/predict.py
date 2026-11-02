from __future__ import annotations

from datetime import datetime
import logging
import os
import traceback
from typing import Any, Dict

from fastapi import APIRouter, HTTPException, Request

from backend.services.prediction_service import (
    assess_diabetes,
    predict_foot,
    predict_final,
    predict_retina,
)
router = APIRouter(tags=["prediction"])
logger = logging.getLogger(__name__)
_MAX_FOOT_UPLOAD_BYTES = 12 * 1024 * 1024


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
        if not isinstance(payload, dict):
            raise HTTPException(
                status_code=422,
                detail="Assessment request must be a JSON object.",
            )
        assessment_model = request.app.state.model_registry.assessment_model
        if assessment_model is None:
            raise HTTPException(
                status_code=503,
                detail="The XGBoost assessment model is unavailable; no result was produced.",
            )
        result = assess_diabetes(payload, model=assessment_model)
        print("ASSESSMENT RESULT:", result)
        print("=" * 60)
        return {"success": True, **result}
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
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
        local_path = None
        storage_url = None
        file_size = None

        if "multipart/form-data" in content_type:
            print("FOOT REQUEST TYPE: multipart/form-data")
            form = await request.form()
            file_obj = form.get("file") or form.get("image")
            if file_obj and hasattr(file_obj, "read"):
                upload_size = getattr(file_obj, "size", None)
                if upload_size is not None and upload_size > _MAX_FOOT_UPLOAD_BYTES:
                    raise HTTPException(
                        status_code=413,
                        detail="Foot image uploads must not exceed 12 MB.",
                    )
                image_input = await file_obj.read(_MAX_FOOT_UPLOAD_BYTES + 1)
                if len(image_input) > _MAX_FOOT_UPLOAD_BYTES:
                    raise HTTPException(
                        status_code=413,
                        detail="Foot image uploads must not exceed 12 MB.",
                    )
                file_size = f"{len(image_input)} bytes"
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
                            file_size = f"{os.path.getsize(clean_path)} bytes"

        if image_input is None:
            raise HTTPException(
                status_code=422,
                detail="A foot image file or image URL is required.",
            )
        if isinstance(image_input, str) and image_input.startswith(
            ("http://", "https://")
        ):
            raise HTTPException(
                status_code=422,
                detail=(
                    "Foot screening requires the image bytes. Upload the image "
                    "using multipart/form-data with the 'file' field."
                ),
            )

        print("==================================================")
        print("BACKEND PREDICT FOOT CALL LOGS:")
        if local_path is not None:
            print(f"  - Local Image Path    : {local_path}")
        if storage_url is not None:
            print(f"  - Storage URL         : {storage_url}")
        if file_size is not None:
            print(f"  - File Size           : {file_size}")
        print("==================================================")

        result = predict_foot(
            image_url=image_input,
        )

        print("FOOT RESULT:", result)
        print("=" * 60)

        return {"success": True, **result}

    except HTTPException:
        raise
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

        assessment_score = (
            assessment_result.get("risk_percentage")
            if isinstance(assessment_result, dict)
            else None
        )
        if (
            isinstance(assessment_score, bool)
            or not isinstance(assessment_score, (int, float))
            or not 0 <= assessment_score <= 100
        ):
            raise HTTPException(status_code=422, detail="Completed assessment result is required")
        if (
            not isinstance(retina_result, dict)
            or not isinstance(retina_result.get("prediction"), str)
            or not retina_result["prediction"].strip()
        ):
            raise HTTPException(status_code=422, detail="Completed retina result is required")
        foot_prediction = (
            foot_result.get("status") or foot_result.get("prediction")
            if isinstance(foot_result, dict)
            else None
        )
        if not isinstance(foot_prediction, str) or not foot_prediction.strip():
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
async def predict_diabetes_alias(request: Request) -> Dict[str, Any]:
    return await predict_assessment_endpoint(request)


@router.post("/predict/foot-ulcer")
async def predict_foot_ulcer_alias(request: Request) -> Dict[str, Any]:
    return await predict_foot_endpoint(request)


@router.post("/predict/multi-modal")
async def predict_multi_modal_alias(request: Request) -> Dict[str, Any]:
    return await predict_final_endpoint(request)
