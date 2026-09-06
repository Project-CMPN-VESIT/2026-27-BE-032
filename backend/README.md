# DiabeticAI backend

This backend exposes the diabetes prediction APIs used by the Flutter client without modifying the frontend UI or Firebase authentication.

## Structure

- `app.py` - FastAPI application entry point
- `models/` - model artifacts and registry loader
- `services/` - prediction business logic
- `routes/` - HTTP route definitions
- `utils/` - environment and configuration helpers

## Start locally

1. Install dependencies:
   `python -m pip install -r backend/requirements.txt`
2. Place trained model files in `backend/models/` or set environment variables:
   - `ASSESSMENT_MODEL_PATH`
   - `RETINA_MODEL_PATH`
   - `FOOT_MODEL_PATH`
   - `FINAL_MODEL_PATH`
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

- The app loads models once at startup via `ModelRegistry.load_all()`.
- If no model file is present, the service falls back to a deterministic clinical heuristic so the API remains functional while preserving the trained artifacts when they are added.
