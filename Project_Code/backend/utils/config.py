from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Project Root
PROJECT_ROOT = BASE_DIR.parent

# Models are inside training folder
MODEL_DIR = PROJECT_ROOT / "training"

# Actual model files
ASSESSMENT_MODEL_PATH = MODEL_DIR / "diabetes_xgboost_model.pkl"

# Retina model: Prefer the full HuggingFace 5-class directory, fallback to .pth
RETINA_MODEL_PATH = MODEL_DIR / "retina_vit"

# Final prediction is a Multimodal Decision Fusion Pipeline (predict_final in prediction_service)
FINAL_MODEL_PATH = None

DEFAULT_MODEL_CANDIDATES = {
    "assessment": [
        "diabetes_xgboost_model.pkl",
    ],
    "retina": [
        "retina_vit",
        "retina_vit.pth",
        "retina_resnet18.pth",
    ],
    "foot": [],
    "final": [],
}

API_TITLE = "DiabeticAI Prediction API"
API_VERSION = "1.0.0"
