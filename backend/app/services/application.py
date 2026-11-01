"""Application service — the candidate-to-vacancy pipeline of the agency.

Business rules enforced here (not in the API layer):
    * both candidate and vacancy must exist;
    * a candidate may apply to the same vacancy only once (409);
    * status transitions are free-form but validated against the enum.
"""

from __future__ import annotations

from app.dto.application import ApplicationCreate, ApplicationRead, ApplicationUpdate
from app.dto.common import Page, PageParams
from app.models.application import ApplicationStatus
from app.repositories.application import ApplicationRepository
from app.repositories.candidate import CandidateRepository
from app.repositories.user import UserRepository
from app.repositories.vacancy import VacancyRepository
from app.services.errors import ConflictError, NotFoundError, ValidationError


class ApplicationService:
    def __init__(
        self,
        repo: ApplicationRepository | None = None,
        candidate_repo: CandidateRepository | None = None,
        vacancy_repo: VacancyRepository | None = None,
        user_repo: UserRepository | None = None,
    ) -> None:
        self._repo = repo or ApplicationRepository()
        self._candidate_repo = candidate_repo or CandidateRepository()
        self._vacancy_repo = vacancy_repo or VacancyRepository()
        self._user_repo = user_repo or UserRepository()

    def list_applications(
        self,
        params: PageParams,
        vacancy_id: int | None = None,
        candidate_id: int | None = None,
        status: ApplicationStatus | None = None,
        manager_id: int | None = None,
    ) -> Page[ApplicationRead]:
        return self._repo.search_paginated(
            params,
            vacancy_id=vacancy_id,
            candidate_id=candidate_id,
            status=status,
            manager_id=manager_id,
        )

    def get_application(self, application_id: int) -> ApplicationRead:
        application = self._repo.get_by_id(application_id)
        if application is None:
            raise NotFoundError(f"Application {application_id} not found")
        return application

    def create_application(self, data: ApplicationCreate) -> ApplicationRead:
        if self._candidate_repo.get_by_id(data.candidate_id) is None:
            raise NotFoundError(f"Candidate {data.candidate_id} not found")
        if self._vacancy_repo.get_by_id(data.vacancy_id) is None:
            raise NotFoundError(f"Vacancy {data.vacancy_id} not found")
        if data.manager_id is not None and self._user_repo.get_by_id(data.manager_id) is None:
            raise ValidationError(f"Manager {data.manager_id} does not exist")
        if self._repo.exists_pair(data.candidate_id, data.vacancy_id):
            raise ConflictError("This candidate already applied to this vacancy")
        return self._repo.create(data)

    def update_application(self, application_id: int, data: ApplicationUpdate) -> ApplicationRead:
        self.get_application(application_id)  # 404 if missing
        if data.manager_id is not None and self._user_repo.get_by_id(data.manager_id) is None:
            raise ValidationError(f"Manager {data.manager_id} does not exist")
        updated = self._repo.update(application_id, data)
        if updated is None:
            raise NotFoundError(f"Application {application_id} not found")
        return updated

    def delete_application(self, application_id: int) -> None:
        if not self._repo.delete(application_id):
            raise NotFoundError(f"Application {application_id} not found")
