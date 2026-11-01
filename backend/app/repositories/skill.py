"""Skill repository — auxiliary dictionary entity (many-to-many with vacancies)."""

from __future__ import annotations

from typing import Sequence

from sqlalchemy import select

from app.db.vis import Vis
from app.dto.skill import SkillCreate, SkillRead
from app.models.skill import Skill
from app.repositories.base import BaseRepository


class SkillRepository(BaseRepository[Skill, SkillRead, SkillCreate, SkillCreate]):
    model = Skill
    read_dto = SkillRead

    def get_by_name(self, name: str) -> SkillRead | None:
        with Vis(self._factory) as session:
            obj = session.scalar(select(Skill).where(Skill.name == name))
            return self._to_read(obj)

    def list_ordered(self) -> list[SkillRead]:
        with Vis(self._factory) as session:
            rows: Sequence[Skill] = session.scalars(select(Skill).order_by(Skill.name)).all()
            return [self._to_read(r) for r in rows]
