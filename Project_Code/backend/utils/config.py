# from pathlib import Path
# import os

# BASE_DIR = Path(__file__).resolve().parent.parent
# MODEL_DIR = Path(os.getenv("MODEL_DIR", str(BASE_DIR / "models")))

# DEFAULT_MODEL_CANDIDATES = {
#     "assessment": [
#         "assessment_model.pkl",
#         "diabetes_model.pkl",
#         "xgboost_diabetes_model.pkl",
#         "diabetes_xgb.pkl",
#     ],
#     "retina": [
#         "retina_model.keras",
#         "retina_model.h5",
#         "retina_model.pt",
#         "retina_model.pth",
#         "retina_unet.keras",
#     ],
#     "foot": [
#         "foot_model.pt",
#         "foot_model.pth",
#         "foot_model.keras",
#         "foot_model.h5",
#         "foot_ulcer_model.pt",
#     ],
#     "final": [
#         "final_model.pkl",
#         "combined_model.pkl",
#         "multi_modal_model.pkl",
#     ],
# }

# ASSESSMENT_MODEL_PATH = Path(os.getenv("ASSESSMENT_MODEL_PATH", str(MODEL_DIR / DEFAULT_MODEL_CANDIDATES["assessment"][0])))
# RETINA_MODEL_PATH = Path(os.getenv("RETINA_MODEL_PATH", str(MODEL_DIR / DEFAULT_MODEL_CANDIDATES["retina"][0])))
# FOOT_MODEL_PATH = Path(os.getenv("FOOT_MODEL_PATH", str(MODEL_DIR / DEFAULT_MODEL_CANDIDATES["foot"][0])))
# FINAL_MODEL_PATH = Path(os.getenv("FINAL_MODEL_PATH", str(MODEL_DIR / DEFAULT_MODEL_CANDIDATES["final"][0])))

# API_TITLE = "DiabeticAI Prediction API"
# API_VERSION = "1.0.0"








from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# Project Root
PROJECT_ROOT = BASE_DIR.parent

# Models are inside training folder
MODEL_DIR = PROJECT_ROOT / "training"

# Actual model files
ASSESSMENT_MODEL_PATH = MODEL_DIR / "diabetes_xgboost_model.pkl"

# Retina model
RETINA_MODEL_PATH = MODEL_DIR / "retina_vit.pth"

# Foot model
FOOT_MODEL_PATH = MODEL_DIR / "dfu_resnet50_fast.keras"

# No final model
FINAL_MODEL_PATH = MODEL_DIR / "final_model.pkl"

DEFAULT_MODEL_CANDIDATES = {
    "assessment": [
        "diabetes_xgboost_model.pkl",
    ],
    "retina": [
        "retina_vit.pth",
        "retina_resnet18.pth",
        "retina_unet.pth",
    ],
    "foot": [
        "dfu_resnet50_fast.keras",
        "dfu_cnn.h5",
    ],
    "final": [
        "final_model.pkl",
    ],
}

API_TITLE = "DiabeticAI Prediction API"
API_VERSION = "1.0.0"