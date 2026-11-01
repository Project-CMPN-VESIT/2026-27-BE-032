from __future__ import annotations

import os
from pathlib import Path

# Ensure writable local cache directories for Keras and Matplotlib
_backend_dir = Path(__file__).resolve().parent
_keras_cache = _backend_dir / ".keras_cache"
_keras_cache.mkdir(exist_ok=True, parents=True)
os.environ.setdefault("KERAS_HOME", str(_keras_cache))

_mpl_cache = _backend_dir / ".mpl_cache"
_mpl_cache.mkdir(exist_ok=True, parents=True)
os.environ.setdefault("MPLCONFIGDIR", str(_mpl_cache))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from backend.models.registry import ModelRegistry
from backend.routes.predict import router as predict_router
from backend.utils.config import API_TITLE, API_VERSION


def create_app() -> FastAPI:
    app = FastAPI(title=API_TITLE, version=API_VERSION)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.state.model_registry = ModelRegistry()

    @app.on_event("startup")
    async def startup_event() -> None:
        app.state.model_registry.load_all()

    app.include_router(predict_router)
    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("backend.app:app", host="0.0.0.0", port=8000, reload=False)
