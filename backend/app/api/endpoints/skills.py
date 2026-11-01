"""Skill endpoints — auxiliary dictionary (many-to-many with vacancies)."""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.api.dependencies.auth import CurrentUser, ManagerOrAdmin
from app.api.dependencies.providers import get_skill_service
from app.dto.skill import SkillCreate, SkillRead
from app.services.errors import ConflictError, NotFoundError
from app.services.skill import SkillService

router = APIRouter(prefix="/skills", tags=["skills"])


@router.get("", response_model=list[SkillRead], summary="All skills (alphabetical)")
def list_skills(
    current_user: CurrentUser,
    service: SkillService = Depends(get_skill_service),
) -> list[SkillRead]:
    return service.list_skills()


@router.post(
    "",
    response_model=SkillRead,
    status_code=status.HTTP_201_CREATED,
    summary="Create a skill (manager/admin)",
)
def create_skill(
    data: SkillCreate,
    current_user: ManagerOrAdmin,
    service: SkillService = Depends(get_skill_service),
) -> SkillRead:
    try:
        return service.create_skill(data)
    except ConflictError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=exc.message) from exc


@router.delete("/{skill_id}", summary="Delete a skill (manager/admin)")
def delete_skill(
    skill_id: int,
    current_user: ManagerOrAdmin,
    service: SkillService = Depends(get_skill_service),
) -> dict[str, str]:
    try:
        service.delete_skill(skill_id)
        return {"status": "deleted"}
    except NotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message) from exc
