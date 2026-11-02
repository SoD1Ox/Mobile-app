"""FastAPI application entry point (staffing agency backend).

Wires together: routers (auth/users/companies/vacancies/candidates/
applications/skills), CORS and domain-exception handlers.
Contains NO business logic — that lives in services.
"""

from __future__ import annotations

import logging

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app import __version__
from app.api.endpoints import (
    applications,
    auth,
    candidates,
    companies,
    skills,
    users,
    vacancies,
)
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
        "Staffing-agency (кадровое агентство) API for the mobile UI.\n\n"
        "Layers: api -> services -> repositories -> SQLAlchemy ORM -> PostgreSQL.\n"
        "DTOs (pydantic) isolate API from ORM; sessions are opened per DB operation "
        "through the ``Vis`` context manager."
    ),
)

_logger = logging.getLogger("uvicorn.error")

# CORS — allow the Flutter client (any origin in dev; tighten in production).
app.add_middleware(
    CORSMiddleware,
    # "*" + allow_credentials=True is an invalid CORS combination (Starlette
    # then drops the Access-Control-Allow-Origin header), which makes browser
    # requests fail with "ClientException: Failed to fetch".  A regex allows
    # any dev origin (localhost / 127.0.0.1 on random flutter-run ports).
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ------------------------------------------------------------------ routers
app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(companies.router, prefix="/api/v1")
app.include_router(companies.contact_router, prefix="/api/v1")
app.include_router(vacancies.router, prefix="/api/v1")
app.include_router(candidates.router, prefix="/api/v1")
app.include_router(applications.router, prefix="/api/v1")
app.include_router(skills.router, prefix="/api/v1")


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
    """Log diagnostic details locally and return a safe message to the client."""
    _logger.error(
        "Unhandled server error for %s %s",
        request.method,
        request.url.path,
        exc_info=(type(exc), exc, exc.__traceback__),
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Внутренняя ошибка сервера. Попробуйте позже."},
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
