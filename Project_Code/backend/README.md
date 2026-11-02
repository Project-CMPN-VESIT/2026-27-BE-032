# DiabeticAI backend

This backend exposes the prediction APIs used by the Flutter client.

## Structure

- `app.py` - FastAPI application entry point
- `models/` - model artifacts and registry loader
- `services/` - prediction business logic
- `routes/` - HTTP route definitions
- `utils/` - environment and configuration helpers

## Start locally

1. Install dependencies:
   `python -m pip install -r backend/requirements.txt`
2. Place the configured assessment and retina model artifacts in the `training/` directory. Their paths are defined in `backend/utils/config.py`.
3. Run the API:
   `uvicorn backend.app:app --host 0.0.0.0 --port 8000`

## Endpoints

- `POST /predict/assessment`
- `POST /predict/retina`
- `POST /predict/foot`
- `POST /predict/final`
- Compatibility aliases:
  - `POST /predict/diabetes`
  - `POST /predict/foot-ulcer`
  - `POST /predict/multi-modal`

## Notes

- `POST /predict/assessment` requires `HighBP`, `HighChol`, `CholCheck`, `BMI`, `Smoker`, `Stroke`, `HeartDiseaseorAttack`, `Age`, `Sex`, and `DiffWalk`, which are collected by the current Flutter form. Other numeric model features are optional; absent answers are not defaulted, and XGBoost inference runs only when its complete feature vector is present. The rule-based assessment uses the required answers and any submitted optional factors.
- The assessment and retina model artifacts are loaded at startup via `ModelRegistry.load_all()`.
- Foot screening accepts JPEG, PNG, and WebP image bytes using multipart/form-data (`file` field), validates dimensions and image quality, then performs a preliminary OpenCV region analysis. It applies bilateral denoising, luminance normalization and CLAHE, compares local luminance/chroma and texture with surrounding regions, uses morphology and connected components, and returns normalized suspicious-region bounds plus image metrics. Remote image URLs are not fetched; submit the actual image bytes.
- The image-analysis categories are `NORMAL`, `MILD FINDING`, `SEVERE FINDING`, and `INCONCLUSIVE`. The heuristic combines local visual cues and is not a trained or clinically validated wound classifier. It cannot confirm wound depth, identify every foot in an image, or diagnose a medical condition. It returns no confidence or clinical risk percentage. Region highlights and metrics are visual screening aids only.
- Unsuitable image bytes return `INCONCLUSIVE`; malformed/missing requests return an explicit HTTP error. The upload-size limit is 12 MB. No Gemini credential or foot model artifact is required.
- The final response preserves the assessment score and qualitative screening findings. It does not calculate an overall medical risk percentage from unrelated scores.
