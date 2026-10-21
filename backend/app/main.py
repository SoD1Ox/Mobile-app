"""FastAPI application entry point (mobile-app backend).

Wires together: routers (auth/users/projects/tasks/clients/tags), CORS and
domain-exception handlers.  Contains NO business logic — that lives in services.
"""

from __future__ import annotations

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app import __version__
from app.api.endpoints import auth, clients, projects, tags, tasks, users
from app.config.settings import settings
from app.services.errors import (
    AuthenticationError,
    ConflictError,
    DomainError,
    NotFoundError,
    PermissionDeniedError,
    ValidationError,
)

app = FastAPI(
    title=settings.api_title,
    version=settings.api_version,
    description=(
        "Task-tracker API for the mobile UI.\n\n"
        "Layers: api -> services -> repositories -> SQLAlchemy ORM -> PostgreSQL.\n"
        "DTOs (pydantic) isolate API from ORM; sessions are opened per DB operation "
        "through the ``Vis`` context manager."
    ),
)

# CORS — allow the Flutter client (any origin in dev; tighten in production).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------------ routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(projects.router, prefix="/api/v1")
app.include_router(tasks.router, prefix="/api/v1")
app.include_router(clients.router, prefix="/api/v1")
app.include_router(tags.router, prefix="/api/v1")


# ------------------------------------------- domain error -> HTTP translation
_DOMAIN_STATUS: dict[type[DomainError], int] = {
    NotFoundError: status.HTTP_404_NOT_FOUND,
    ConflictError: status.HTTP_409_CONFLICT,
    AuthenticationError: status.HTTP_401_UNAUTHORIZED,
    PermissionDeniedError: status.HTTP_403_FORBIDDEN,
    ValidationError: status.HTTP_422_UNPROCESSABLE_ENTITY,
}


@app.exception_handler(DomainError)
async def domain_error_handler(request: Request, exc: DomainError) -> JSONResponse:
    """Safety net: any domain error escaping an endpoint becomes a clean JSON message."""
    code = status.HTTP_400_BAD_REQUEST
    for err_type, http_code in _DOMAIN_STATUS.items():
        if isinstance(exc, err_type):
            code = http_code
            break
    return JSONResponse(status_code=code, content={"detail": exc.message})


@app.exception_handler(Exception)
async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
    """Never leak stack traces to the client; return a readable error message."""
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": f"Internal server error: {exc}"},
    )


@app.get("/health", tags=["meta"], summary="Liveness probe")
def health() -> dict[str, str]:
    return {"status": "ok", "version": __version__}


@app.get("/", tags=["meta"], summary="API index")
def index() -> dict[str, str]:
    return {
        "name": settings.api_title,
        "docs": "/docs",
        "health": "/health",
        "api_prefix": "/api/v1",
    }
