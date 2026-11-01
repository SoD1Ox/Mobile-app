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
        assigned_worker_id: int | None = None,
    ) -> Page[ApplicationRead]:
        return self._repo.search_paginated(
            params,
            vacancy_id=vacancy_id,
            candidate_id=candidate_id,
            status=status,
            manager_id=manager_id,
            assigned_worker_id=assigned_worker_id,
        )

    def stats(self, user_id: int | None = None, scoped_worker: bool = False) -> dict:
        """Dashboard aggregates: total + per-status counts in one GROUP BY.

        For a worker the numbers are scoped to their own assignments so the
        tiles show their personal queue, not the whole agency funnel.
        ``mine`` additionally returns the count assigned to this user for any
        role (used by the "Мои кейсы" tile on manager dashboards).
        """
        return self._repo.status_counts(
            assigned_worker_id=user_id if scoped_worker else None,
            mine_user_id=user_id,
        )

    def get_application(self, application_id: int) -> ApplicationRead:
        application = self._repo.get_by_id(application_id)
        if application is None:
            raise NotFoundError(f"Application {application_id} not found")
        return application

    def create_application(self, data: ApplicationCreate) -> ApplicationRead:
        """Register an application.

        Two flows:
          * agency staff apply an existing candidate (``candidate_id``);
          * self-application from the vacancy card — no candidate yet, then a
            lightweight Candidate record is created from full_name/email/phone.
        """
        from app.dto.candidate import CandidateCreate

        payload = data.model_dump()
        candidate_id = payload.pop("candidate_id", None)
        full_name = payload.pop("full_name", None)
        email = payload.pop("email", None)
        phone = payload.pop("phone", None)

        if candidate_id is not None:
            if self._candidate_repo.get_by_id(candidate_id) is None:
                raise NotFoundError(f"Candidate {candidate_id} not found")
        else:
            if not full_name:
                raise ValidationError(
                    "Provide candidate_id or full_name for a self-application"
                )
            created = self._candidate_repo.create(
                CandidateCreate(
                    full_name=full_name,
                    email=email,
                    phone=phone,
                    specialization=None,
                    city=None,
                    experience_years=0,
                    resume_url=None,
                )
            )
            candidate_id = created.id

        if self._vacancy_repo.get_by_id(data.vacancy_id) is None:
            raise NotFoundError(f"Vacancy {data.vacancy_id} not found")
        if data.manager_id is not None and self._user_repo.get_by_id(data.manager_id) is None:
            raise ValidationError(f"Manager {data.manager_id} does not exist")
        if (
            data.assigned_worker_id is not None
            and self._user_repo.get_by_id(data.assigned_worker_id) is None
        ):
            raise ValidationError(f"Worker {data.assigned_worker_id} does not exist")
        if self._repo.exists_pair(candidate_id, data.vacancy_id):
            raise ConflictError("This candidate already applied to this vacancy")
        return self._repo.create(
            ApplicationCreate(candidate_id=candidate_id, **payload)
        )

    def update_application(self, application_id: int, data: ApplicationUpdate) -> ApplicationRead:
        self.get_application(application_id)  # 404 if missing
        if data.manager_id is not None and self._user_repo.get_by_id(data.manager_id) is None:
            raise ValidationError(f"Manager {data.manager_id} does not exist")
        if (
            data.assigned_worker_id is not None
            and self._user_repo.get_by_id(data.assigned_worker_id) is None
        ):
            raise ValidationError(f"Worker {data.assigned_worker_id} does not exist")
        updated = self._repo.update(application_id, data)
        if updated is None:
            raise NotFoundError(f"Application {application_id} not found")
        return updated

    def delete_application(self, application_id: int) -> None:
        if not self._repo.delete(application_id):
            raise NotFoundError(f"Application {application_id} not found")
