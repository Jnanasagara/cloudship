import os
from fastapi import FastAPI
from fastapi.responses import JSONResponse

def create_app() -> FastAPI:
    version = os.environ.get("APP_VERSION", "local-dev")

    allow_demo = os.environ.get("ALLOW_FAILURE_DEMO", "false").strip().lower() == "true"
    simulate_unhealthy = os.environ.get("SIMULATE_UNHEALTHY", "false").strip().lower() == "true"

    if simulate_unhealthy and not allow_demo:
        raise ValueError("SIMULATE_UNHEALTHY requires ALLOW_FAILURE_DEMO=true")

    application = FastAPI(title="CloudShip")

    @application.get("/")
    async def root() -> dict[str, str]:
        return {
            "service": "cloudship",
            "message": "CloudShip running",
        }

    @application.get("/health")
    async def health() -> JSONResponse:
        if simulate_unhealthy:
            return JSONResponse(
                status_code=503,
                content={"status": "unhealthy"},
            )
        
        return JSONResponse(
            status_code=200,
            content={"status": "healthy"},
        )

    @application.get("/version")
    async def version_info() -> dict[str, str]:
        return {
            "service": "cloudship",
            "version": version
        }

    return application