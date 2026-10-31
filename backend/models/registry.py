from __future__ import annotations

import logging
import traceback
from pathlib import Path
from typing import Any, Dict, Optional

import joblib
import tensorflow as tf
import torch

from backend.utils.config import (
    ASSESSMENT_MODEL_PATH,
    DEFAULT_MODEL_CANDIDATES,
    FINAL_MODEL_PATH,
    FOOT_MODEL_PATH,
    MODEL_DIR,
    RETINA_MODEL_PATH,
)

logger = logging.getLogger(__name__)


class ModelRegistry:
    def __init__(self) -> None:
        self.assessment_model: Any = None
        self.retina_model: Any = None
        self.foot_model: Any = None
        self.final_model: Any = None

    def _resolve_model_path(
        self,
        model_key: str,
        configured_path: Path,
    ) -> Optional[Path]:
        if configured_path.exists():
            return configured_path.resolve()

        for name in DEFAULT_MODEL_CANDIDATES.get(model_key, []):
            candidate = MODEL_DIR / name
            if candidate.exists():
                return candidate.resolve()

        return None

    def _load_pickle(self, path: Path):
        return joblib.load(path)

    def _load_keras(self, path: Path):
        return tf.keras.models.load_model(path)

    def _load_torch(self, path: Path):
        obj = torch.load(path, map_location="cpu")
        if isinstance(obj, dict) or type(obj).__name__ == "OrderedDict":
            print(f"[REGISTRY] PyTorch model at {path} is a state_dict. Instantiating ViT model architecture...")
            try:
                from transformers import ViTForImageClassification
                model = ViTForImageClassification.from_pretrained(
                    "google/vit-base-patch16-224",
                    num_labels=5,
                    ignore_mismatched_sizes=True,
                )
                model.load_state_dict(obj, strict=False)
                model.eval()
                print("[REGISTRY] [OK] Successfully loaded state_dict into ViTForImageClassification!")
                return model
            except Exception as exc:
                print(f"[REGISTRY] [WARN] ViT instantiation failed ({exc}). Falling back to ResNet-18 architecture...")
                import torchvision.models as tv_models
                import torch.nn as nn
                model = tv_models.resnet18()
                model.fc = nn.Linear(model.fc.in_features, 5)
                model.load_state_dict(obj, strict=False)
                model.eval()
                print("[REGISTRY] [OK] Successfully loaded state_dict into ResNet-18!")
                return model
        else:
            if hasattr(obj, "eval"):
                obj.eval()
            return obj

    def _load_auto(self, path: Path):
        suffix = path.suffix.lower()
        if suffix in [".keras", ".h5"]:
            return self._load_keras(path)
        if suffix in [".pt", ".pth"]:
            return self._load_torch(path)
        if suffix in [".pkl", ".joblib"]:
            return self._load_pickle(path)
        raise ValueError(f"Unsupported model format: {path}")

    def load_all(self) -> Dict[str, Optional[str]]:
        loaded: Dict[str, Optional[str]] = {}

        models = {
            "assessment": ("Assessment model loaded", ASSESSMENT_MODEL_PATH),
            "retina": ("Retina model loaded", RETINA_MODEL_PATH),
            "foot": ("Foot model loaded", FOOT_MODEL_PATH),
            "final": ("Final model loaded", FINAL_MODEL_PATH),
        }

        print("=" * 60)
        print("LOADING MACHINE LEARNING MODELS...")
        print("=" * 60)

        for key, (success_msg, configured_path) in models.items():
            path = self._resolve_model_path(key, configured_path)

            if path is None:
                print(f"[REGISTRY] [WARN] FAILED to load {key} model: Model file path not found (Configured: {configured_path})")
                logger.warning("%s model not found.", key)
                setattr(self, f"{key}_model", None)
                loaded[key] = None
                continue

            print(f"[REGISTRY] Model [{key}] path: {path.absolute()}")
            try:
                model = self._load_auto(path)
                setattr(self, f"{key}_model", model)
                loaded[key] = str(path)
                print(f"[REGISTRY] [OK] {success_msg}")
                logger.info("%s model loaded successfully from %s", key, path)
            except Exception as e:
                print(f"[REGISTRY] [ERROR] FAILED to load {key} model from {path}: {e}")
                traceback.print_exc()
                logger.exception("Failed loading %s model", key)
                setattr(self, f"{key}_model", None)
                loaded[key] = None

        print("=" * 60)
        print("MODEL REGISTRY LOADING COMPLETE:", loaded)
        print("=" * 60)

        return loaded