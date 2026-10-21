"""Tag endpoints (auxiliary entity for the tasks <-> tags many-to-many relation)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies.auth import CurrentUser, ManagerOrAdmin
from app.dto.tag import TagCreate, TagRead
from app.services.errors import ConflictError, NotFoundError
from app.services.tag import TagService

router = APIRouter(prefix="/tags", tags=["tags"])


def get_tag_service() -> TagService:
    return TagService()


@router.get("", response_model=list[TagRead], summary="List all tags")
def list_tags(
    current_user: CurrentUser,
    service: TagService = Depends(get_tag_service),
) -> list[TagRead]:
    return service.list_tags()


@router.post("", response_model=TagRead, status_code=status.HTTP_201_CREATED,
             summary="Create a tag (manager/admin)")
def create_tag(
    data: TagCreate,
    current_user: ManagerOrAdmin,
    service: TagService = Depends(get_tag_service),
) -> TagRead:
    try:
        return service.create_tag(data)
    except ConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.message) from exc


@router.delete("/{tag_id}", summary="Delete a tag (manager/admin)")
def delete_tag(
    tag_id: int,
    current_user: ManagerOrAdmin,
    service: TagService = Depends(get_tag_service),
) -> dict[str, str]:
    try:
        service.delete_tag(tag_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message) from exc
