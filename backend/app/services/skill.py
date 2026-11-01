"""Skill service — thin wrapper over the dictionary repository."""

from __future__ import annotations

from app.dto.skill import SkillCreate, SkillRead
from app.repositories.skill import SkillRepository
from app.services.errors import ConflictError, NotFoundError


class SkillService:
    def __init__(self, repo: SkillRepository | None = None) -> None:
        self._repo = repo or SkillRepository()

    def list_skills(self) -> list[SkillRead]:
        return self._repo.list_ordered()

    def create_skill(self, data: SkillCreate) -> SkillRead:
        if self._repo.get_by_name(data.name) is not None:
            raise ConflictError(f"Skill '{data.name}' already exists")
        return self._repo.create(data)

    def delete_skill(self, skill_id: int) -> None:
        if not self._repo.delete(skill_id):
            raise NotFoundError(f"Skill {skill_id} not found")
