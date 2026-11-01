"""Candidate endpoints (main entity — job seekers) + recruiter notes.

Large-data mechanism: paginated list + filters (city / specialization) +
ILIKE search over name / specialization / e-mail.

RBAC:
    read            — any authenticated user;
    create/update   — manager / admin;
    delete          — admin only;
    comments        — authenticated (author recorded automatically).
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.api.dependencies.auth import AdminUser, CurrentUser, ManagerOrAdmin
from app.api.dependencies.providers import get_candidate_service
from app.dto.candidate import CandidateCreate, CandidateRead, CandidateUpdate
from app.dto.comment import CommentCreate, CommentRead
from app.dto.common import Page, PageParams
from app.services.candidate import CandidateService
from app.services.errors import ConflictError, DomainError, NotFoundError

router = APIRouter(prefix="/candidates", tags=["candidates"])


def _http_error(exc: DomainError) -> HTTPException:
    if isinstance(exc, NotFoundError):
        return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message)
    if isinstance(exc, ConflictError):
        return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.message)
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=exc.message)


@router.get("", response_model=Page[CandidateRead], summary="Paginated candidate list")
def list_candidates(
    current_user: CurrentUser,
    service: CandidateService = Depends(get_candidate_service),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=200),
    search: str | None = Query(default=None, max_length=200),
    city: str | None = Query(default=None, max_length=80),
    specialization: str | None = Query(default=None, max_length=100),
) -> Page[CandidateRead]:
    return service.list_candidates(
        PageParams(page=page, page_size=page_size, search=search),
        city=city,
        specialization=specialization,
    )


@router.get("/{candidate_id}", response_model=CandidateRead, summary="Get a single candidate")
def get_candidate(
    candidate_id: int,
    current_user: CurrentUser,
    service: CandidateService = Depends(get_candidate_service),
) -> CandidateRead:
    try:
        return service.get_candidate(candidate_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post(
    "",
    response_model=CandidateRead,
    status_code=status.HTTP_201_CREATED,
    summary="Add a candidate (manager/admin)",
)
def create_candidate(
    data: CandidateCreate,
    current_user: ManagerOrAdmin,
    service: CandidateService = Depends(get_candidate_service),
) -> CandidateRead:
    try:
        return service.create_candidate(data)
    except ConflictError as exc:
        raise _http_error(exc) from exc


@router.put("/{candidate_id}", response_model=CandidateRead, summary="Update a candidate (manager/admin)")
def update_candidate(
    candidate_id: int,
    data: CandidateUpdate,
    current_user: ManagerOrAdmin,
    service: CandidateService = Depends(get_candidate_service),
) -> CandidateRead:
    try:
        return service.update_candidate(candidate_id, data)
    except (NotFoundError, ConflictError) as exc:
        raise _http_error(exc) from exc


@router.delete("/{candidate_id}", summary="Delete a candidate (admin)")
def delete_candidate(
    candidate_id: int,
    current_user: AdminUser,
    service: CandidateService = Depends(get_candidate_service),
) -> dict[str, str]:
    try:
        service.delete_candidate(candidate_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise _http_error(exc) from exc


# ------------------------------------------------------------------ notes
@router.get(
    "/{candidate_id}/comments", response_model=list[CommentRead], summary="Recruiter notes"
)
def list_comments(
    candidate_id: int,
    current_user: CurrentUser,
    service: CandidateService = Depends(get_candidate_service),
) -> list[CommentRead]:
    try:
        return service.list_comments(candidate_id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc


@router.post(
    "/{candidate_id}/comments",
    response_model=CommentRead,
    status_code=status.HTTP_201_CREATED,
    summary="Add a recruiter note (authenticated)",
)
def add_comment(
    candidate_id: int,
    data: CommentCreate,
    current_user: CurrentUser,
    service: CandidateService = Depends(get_candidate_service),
) -> CommentRead:
    try:
        return service.add_comment(candidate_id, data, author_id=current_user.id)
    except NotFoundError as exc:
        raise _http_error(exc) from exc
