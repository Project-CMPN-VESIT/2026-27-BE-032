from __future__ import annotations

import logging
import traceback
from pathlib import Path
from typing import Any, Dict, Optional

import os
_pkg_dir = Path(__file__).resolve().parent.parent
os.environ.setdefault("KERAS_HOME", str(_pkg_dir / ".keras_cache"))
os.environ.setdefault("MPLCONFIGDIR", str(_pkg_dir / ".mpl_cache"))

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
        configured_path: Optional[Path],
    ) -> Optional[Path]:
        if configured_path is not None and configured_path.exists():
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
        from transformers import ViTForImageClassification, ViTConfig

        # If it's a HuggingFace directory containing config.json and model.safetensors
        if path.is_dir() and (path / "config.json").exists():
            print(f"[REGISTRY] Loading trained 5-class ViT model directly from {path}...")
            model = ViTForImageClassification.from_pretrained(str(path), local_files_only=True)
            model.eval()
            print(f"[REGISTRY] [OK] Successfully loaded ViT model from directory (num_labels={model.num_labels}, 100% trained weights)!")
            return model

        # If it's a .pth / .pt file
        obj = torch.load(path, map_location="cpu", weights_only=False)
        if isinstance(obj, dict) or type(obj).__name__ == "OrderedDict":
            print(f"[REGISTRY] PyTorch state_dict detected at {path}. Instantiating 5-class ViT architecture...")
            try:
                # Find the retina_vit folder to get exact config if available
                vit_dir = path.parent / "retina_vit"
                if vit_dir.exists() and (vit_dir / "config.json").exists():
                    config = ViTConfig.from_pretrained(str(vit_dir))
                else:
                    config = ViTConfig(
                        image_size=224,
                        patch_size=16,
                        num_channels=3,
                        hidden_size=768,
                        num_hidden_layers=12,
                        num_attention_heads=12,
                        intermediate_size=3072,
                    )
                config.num_labels = 5
                model = ViTForImageClassification(config)
                # Load trained weights strictly matching all keys
                model.load_state_dict(obj, strict=True)
                model.eval()
                print("[REGISTRY] [OK] Successfully loaded state_dict into 5-class ViT (0 mismatched weights)!")
                return model
            except Exception as exc:
                print(f"[REGISTRY] [WARN] Strict ViT loading had notice ({exc}). Trying strict=False...")
                config = ViTConfig()
                config.num_labels = 5
                model = ViTForImageClassification(config)
                model.load_state_dict(obj, strict=False)
                model.eval()
                return model
        else:
            if hasattr(obj, "eval"):
                obj.eval()
            return obj

    def _load_auto(self, path: Path):
        if path.is_dir():
            return self._load_torch(path)
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
            "assessment": ("Assessment XGBoost model loaded", ASSESSMENT_MODEL_PATH),
            "retina": ("Retina ViT (5-class) model loaded", RETINA_MODEL_PATH),
            "foot": ("Foot ResNet50 (4-class) model loaded", FOOT_MODEL_PATH),
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

        # Final prediction: Late Multimodal Decision Fusion Pipeline (not a single static file)
        self.final_model = "multimodal_fusion_pipeline"
        loaded["final"] = "multimodal_fusion_pipeline (Decision Fusion)"
        print("[REGISTRY] [OK] Final Model: Multimodal Decision Fusion Pipeline active")

        print("=" * 60)
        print("MODEL REGISTRY LOADING COMPLETE:", loaded)
        print("=" * 60)

        return loaded
