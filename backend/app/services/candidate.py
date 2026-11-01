"""Candidate service — job seekers + recruiter notes (comments)."""

from __future__ import annotations

from app.dto.candidate import CandidateCreate, CandidateRead, CandidateUpdate
from app.dto.comment import CommentCreate, CommentRead
from app.dto.common import Page, PageParams
from app.repositories.candidate import CandidateRepository
from app.repositories.comment import CommentRepository
from app.services.errors import ConflictError, NotFoundError


class CandidateService:
    def __init__(
        self,
        repo: CandidateRepository | None = None,
        comment_repo: CommentRepository | None = None,
    ) -> None:
        self._repo = repo or CandidateRepository()
        self._comment_repo = comment_repo or CommentRepository()

    def list_candidates(
        self, params: PageParams, city: str | None = None, specialization: str | None = None
    ) -> Page[CandidateRead]:
        return self._repo.search_paginated(params, city=city, specialization=specialization)

    def get_candidate(self, candidate_id: int) -> CandidateRead:
        candidate = self._repo.get_by_id(candidate_id)
        if candidate is None:
            raise NotFoundError(f"Candidate {candidate_id} not found")
        return candidate

    def create_candidate(self, data: CandidateCreate) -> CandidateRead:
        if data.email and self._repo.get_by_email(data.email) is not None:
            raise ConflictError(f"Candidate with e-mail {data.email} already exists")
        return self._repo.create(data)

    def update_candidate(self, candidate_id: int, data: CandidateUpdate) -> CandidateRead:
        self.get_candidate(candidate_id)  # 404 if missing
        if data.email:
            other = self._repo.get_by_email(data.email)
            if other is not None and other.id != candidate_id:
                raise ConflictError(f"Candidate with e-mail {data.email} already exists")
        updated = self._repo.update(candidate_id, data)
        if updated is None:
            raise NotFoundError(f"Candidate {candidate_id} not found")
        return updated

    def delete_candidate(self, candidate_id: int) -> None:
        if not self._repo.delete(candidate_id):
            raise NotFoundError(f"Candidate {candidate_id} not found")

    # ------------------------------------------------------------------ notes
    def list_comments(self, candidate_id: int) -> list[CommentRead]:
        self.get_candidate(candidate_id)  # 404 if missing
        return self._comment_repo.list_by_candidate(candidate_id)

    def add_comment(self, candidate_id: int, data: CommentCreate, author_id: int) -> CommentRead:
        self.get_candidate(candidate_id)  # 404 if missing
        # The nested route supplies the candidate id; a mismatched body value is ignored.
        data = data.model_copy(update={"candidate_id": candidate_id})
        return self._comment_repo.create_for_candidate(data, author_id)
