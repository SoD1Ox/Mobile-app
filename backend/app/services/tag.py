"""Tag service — business logic for the ``tags`` auxiliary entity."""

from __future__ import annotations

from app.dto.tag import TagCreate, TagRead
from app.repositories.tag import TagRepository
from app.services.errors import ConflictError, NotFoundError


class TagService:
    def __init__(self, repo: TagRepository | None = None) -> None:
        self._repo = repo or TagRepository()

    def list_tags(self) -> list[TagRead]:
        return self._repo.list_ordered()

    def get_tag(self, tag_id: int) -> TagRead:
        tag = self._repo.get_by_id(tag_id)
        if tag is None:
            raise NotFoundError(f"Tag {tag_id} not found")
        return tag

    def create_tag(self, data: TagCreate) -> TagRead:
        normalized = TagCreate(name=data.name.strip().lower())
        existing = [t for t in self._repo.list_ordered() if t.name == normalized.name]
        if existing:
            raise ConflictError(f"Tag '{normalized.name}' already exists")
        return self._repo.create(normalized)

    def delete_tag(self, tag_id: int) -> None:
        if not self._repo.delete(tag_id):
            raise NotFoundError(f"Tag {tag_id} not found")
