from __future__ import annotations

import logging
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
async def predict_assessment_endpoint(request: Request, payload: Dict[str, Any]) -> Dict[str, Any]:
    try:
        print("=" * 60)
        print("ASSESSMENT PAYLOAD:", payload)
        result = assess_diabetes(payload, model=request.app.state.model_registry.assessment_model)
        print("ASSESSMENT RESULT:", result)
        print("=" * 60)
        return {"success": True, **result}
    except Exception as exc:
        print("❌ ASSESSMENT ENDPOINT ERROR:", exc)
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Assessment prediction failed: {exc}") from exc


@router.post("/predict/retina")
async def predict_retina_endpoint(request: Request, payload: Dict[str, Any]) -> Dict[str, Any]:
    try:
        print("=" * 60)
        print("RETINA PAYLOAD:", payload)

        image_url = (
            payload.get("imageUrl")
            or payload.get("image_url")
            or payload.get("url")
        )

        print("RETINA IMAGE URL:", image_url)

        result = predict_retina(
            image_url=image_url,
            model=request.app.state.model_registry.retina_model,
        )

        print("RETINA RESULT:", result)
        print("=" * 60)

        return {"success": True, **result}

    except Exception as exc:
        print("❌ RETINA ENDPOINT ERROR:", exc)
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Retina prediction failed: {exc}",
        ) from exc


@router.post("/predict/foot")
async def predict_foot_endpoint(request: Request, payload: Dict[str, Any]) -> Dict[str, Any]:
    try:
        print("=" * 60)
        print("FOOT PAYLOAD:", payload)

        image_url = (
            payload.get("imageUrl")
            or payload.get("image_url")
            or payload.get("url")
        )

        print("FOOT IMAGE URL:", image_url)

        result = predict_foot(
            image_url=image_url,
            model=request.app.state.model_registry.foot_model,
        )

        print("FOOT RESULT:", result)
        print("=" * 60)

        return {"success": True, **result}

    except Exception as exc:
        print("❌ FOOT ENDPOINT ERROR:", exc)
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Foot prediction failed: {exc}",
        ) from exc


@router.post("/predict/final")
async def predict_final_endpoint(request: Request, payload: Dict[str, Any]) -> Dict[str, Any]:
    try:
        print("=" * 60)
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
        print("❌ FINAL ENDPOINT ERROR:")
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
