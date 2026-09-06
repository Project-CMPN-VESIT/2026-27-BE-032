from __future__ import annotations

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
