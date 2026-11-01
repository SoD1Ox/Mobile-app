"""Vacancy service — validates FK references and delegates to the repository."""

from __future__ import annotations

from decimal import Decimal

from app.dto.common import Page, PageParams
from app.dto.vacancy import VacancyCreate, VacancyRead, VacancyUpdate
from app.repositories.company import CompanyRepository
from app.repositories.skill import SkillRepository
from app.repositories.vacancy import VacancyRepository
from app.services.errors import NotFoundError, ValidationError


class VacancyService:
    def __init__(
        self,
        repo: VacancyRepository | None = None,
        company_repo: CompanyRepository | None = None,
        skill_repo: SkillRepository | None = None,
    ) -> None:
        self._repo = repo or VacancyRepository()
        self._company_repo = company_repo or CompanyRepository()
        self._skill_repo = skill_repo or SkillRepository()

    def _validate_refs(self, company_id: int | None, skill_ids: list[int] | None) -> None:
        if company_id is not None and not self._company_repo.exists(company_id):
            raise ValidationError(f"Company {company_id} does not exist")
        if skill_ids:
            known = {s.id for s in self._skill_repo.list_all()}
            missing = [sid for sid in skill_ids if sid not in known]
            if missing:
                raise ValidationError(f"Unknown skill ids: {missing}")

    def list_vacancies(
        self,
        params: PageParams,
        company_id: int | None = None,
        city: str | None = None,
        remote: bool | None = None,
        salary_min: Decimal | None = None,
    ) -> Page[VacancyRead]:
        return self._repo.search_paginated(
            params, company_id=company_id, city=city, remote=remote, salary_min=salary_min
        )

    def get_vacancy(self, vacancy_id: int) -> VacancyRead:
        vacancy = self._repo.get_with_skills(vacancy_id)
        if vacancy is None:
            raise NotFoundError(f"Vacancy {vacancy_id} not found")
        return vacancy

    def create_vacancy(self, data: VacancyCreate) -> VacancyRead:
        self._validate_refs(data.company_id, data.skill_ids)
        return self._repo.create_with_skills(data, data.skill_ids)

    def update_vacancy(self, vacancy_id: int, data: VacancyUpdate) -> VacancyRead:
        self.get_vacancy(vacancy_id)  # 404 if missing
        self._validate_refs(data.company_id, data.skill_ids)
        updated = self._repo.update_with_skills(vacancy_id, data)
        if updated is None:
            raise NotFoundError(f"Vacancy {vacancy_id} not found")
        return updated

    def delete_vacancy(self, vacancy_id: int) -> None:
        if not self._repo.delete(vacancy_id):
            raise NotFoundError(f"Vacancy {vacancy_id} not found")

    def list_by_company(self, company_id: int) -> list[VacancyRead]:
        if not self._company_repo.exists(company_id):
            raise NotFoundError(f"Company {company_id} not found")
        return self._repo.list_by_company(company_id)
